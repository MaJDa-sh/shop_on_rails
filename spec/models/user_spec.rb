require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, role: :admin) }
  let(:moderator_user) { create(:user, role: :moderator) }
  let(:regular_user) { create(:user, role: :regular) }
  let(:unactivated_user) { create(:user, active: false) }
  let(:two_factor_enabled_user) { create(:user) }

  before do
    allow(UserMailer).to receive_message_chain(:send_2fa_code, :deliver_later).and_return(true)
    allow(UserMailer).to receive_message_chain(:send_reset_code, :deliver_later).and_return(true)

    @redis_mock = double('Redis')
    allow(Redis).to receive(:current).and_return(@redis_mock)
  end

  describe 'validations' do
    it { should validate_presence_of(:mail) }
    it { should validate_uniqueness_of(:mail) }
    it { should validate_presence_of(:password_digest) }
    it { should validate_uniqueness_of(:phone).allow_nil }

    it 'is valid with valid attributes' do
      expect(build(:user)).to be_valid
    end

    it 'is invalid without a mail' do
      expect(build(:user, mail: nil)).not_to be_valid
    end

    it 'is invalid with a duplicate mail' do
      create(:user, mail: 'test@example.com')
      expect(build(:user, mail: 'test@example.com')).not_to be_valid
    end

    it 'is invalid without a password digest' do
      user_without_password = build(:user)
      user_without_password.password = nil
      user_without_password.password_confirmation = nil
      user_without_password.valid?
      expect(user_without_password.errors[:password_digest]).to include("can't be blank")
    end

    it 'is invalid with a duplicate phone if present' do
      create(:user, phone: '123456789')
      expect(build(:user, phone: '123456789')).not_to be_valid
    end
  end

  describe 'associations' do
    it { should have_one(:user_detail).dependent(:destroy) }
    it { should have_one(:user_settings).dependent(:destroy) }
    it { should have_one(:activation_code).dependent(:destroy) }
    it { should have_one(:verification_code).dependent(:destroy) }
    it { should have_one(:second_factor_code).dependent(:destroy) }
    it { should have_one(:reset_code).dependent(:destroy) }
    it { should have_many(:user_actions).dependent(:destroy) }
    it { should have_many(:blacklisted_tokens).dependent(:destroy) }

    it 'accepts nested attributes for user_detail' do
      user_with_details = build(:user, user_detail_attributes: { first_name: 'John', last_name: 'Doe' })
      expect { user_with_details.save }.to change(UserDetail, :count).by(1)
      expect(user_with_details.user_detail).to be_present
      expect(user_with_details.user_detail.first_name).to eq('John')
    end
  end

  describe '.authenticate_user' do
    let(:password) { 'SecurePassword123!' }
    let!(:auth_user) { create(:user, password: password, password_confirmation: password) }

    context 'when 2FA is not enabled' do
      before do
        auth_user.user_settings.update!(two_factor_enabled: false)
        expect(@redis_mock).to receive(:set).with(instance_of(String), 'active',
                                                  ex: an_instance_of(Integer)).and_return(true)
      end

      it 'returns user and token for valid credentials' do
        result = User.authenticate_user(auth_user.mail, password)
        expect(result[:status]).to eq(:ok)
        expect(result[:user]).to eq(auth_user)
        expect(result[:token]).to be_present
        expect(result[:errors]).to be_nil
      end
    end

    context 'when 2FA is enabled' do
      before do
        two_factor_enabled_user.create_user_settings(two_factor_enabled: true)
        expect(@redis_mock).to receive(:set).with(instance_of(String), instance_of(String),
                                                  ex: an_instance_of(Integer)).and_return(true)
      end

      it 'sends 2FA code and returns accepted status' do
        result = User.authenticate_user(two_factor_enabled_user.mail, password)
        expect(result[:status]).to eq(:accepted)
        expect(result[:message]).to eq('2FA code sent to your email')
        expect(result[:user]).to eq(two_factor_enabled_user)
        expect(result[:token]).to be_nil
        expect(result[:errors]).to be_nil
      end

      context 'when Redis connection fails for 2FA code generation' do
        before do
          expect(@redis_mock).to receive(:set).and_raise(Redis::CannotConnectError)
          two_factor_enabled_user.second_factor_code&.destroy
          allow_any_instance_of(User).to receive(:create_second_factor_code).and_call_original
        end

        it 'falls back to database and sends 2FA code' do
          result = User.authenticate_user(two_factor_enabled_user.mail, password)
          expect(result[:status]).to eq(:accepted)
          expect(result[:message]).to eq('2FA code sent to your email')
          expect(result[:user]).to eq(two_factor_enabled_user)
          expect(two_factor_enabled_user.reload.second_factor_code).to be_present
        end
      end
    end

    it 'returns unauthorized for invalid credentials' do
      result = User.authenticate_user(auth_user.mail, 'wrong_password')
      expect(result[:status]).to eq(:unauthorized)
      expect(result[:user]).to be_nil
      expect(result[:token]).to be_nil
      expect(result[:errors]).to include('Invalid email or password')
    end

    it 'returns unauthorized if user is not found' do
      result = User.authenticate_user('nonexistent@example.com', 'password')
      expect(result[:status]).to eq(:unauthorized)
      expect(result[:user]).to be_nil
      expect(result[:token]).to be_nil
      expect(result[:errors]).to include('Invalid email or password')
    end
  end

  describe '#generate_2fa_code' do
    let!(:user_with_settings) { create(:user) }
    before do
      allow(UserMailer).to receive_message_chain(:send_2fa_code, :deliver_later).and_return(true)
    end

    context 'when Redis is available' do
      before do
        expect(@redis_mock).to receive(:set).with(instance_of(String), instance_of(String),
                                                  ex: an_instance_of(Integer)).and_return(true)
        user_with_settings.create_second_factor_code(code: 'old_code')
        expect(user_with_settings.second_factor_code).to receive(:destroy).at_least(1).and_return(true)
      end

      it 'generates and stores 2FA code in Redis' do
        user_with_settings.generate_2fa_code
      end
    end

    context 'when Redis connection fails' do
      before do
        expect(@redis_mock).to receive(:set).and_raise(Redis::CannotConnectError)
        user_with_settings.second_factor_code&.destroy
      end

      it 'falls back to storing 2FA code in database' do
        user_with_settings.generate_2fa_code
        expect(user_with_settings.reload.second_factor_code).to be_present
        expect(user_with_settings.second_factor_code.code).to be_present
      end
    end
  end

  describe '#verify_2fa_code' do
    let(:valid_code) { 'valid_2fa_code' }
    let(:invalid_code) { 'invalid_2fa_code' }
    let!(:user_for_2fa_verification) { create(:user) }

    context 'when 2FA code is stored in Redis' do
      before do
        expect(@redis_mock).to receive(:get).with("user:#{user_for_2fa_verification.id}:2fa_code").and_return(valid_code)
        expect(@redis_mock).to receive(:del).with("user:#{user_for_2fa_verification.id}:2fa_code").and_return(1)
        user_for_2fa_verification.second_factor_code&.destroy
        allow(user_for_2fa_verification).to receive_message_chain(:second_factor_code, :destroy).and_return(true)
        allow(user_for_2fa_verification).to receive(:generate_jwt).and_return('fake_jwt_token')
      end

      it 'returns token and ok status for valid code' do
        result = user_for_2fa_verification.verify_2fa_code(valid_code)
        expect(result[:status]).to eq(:ok)
        expect(result[:token]).to eq('fake_jwt_token')
        expect(result[:errors]).to be_nil
      end

      it 'returns unauthorized for invalid code' do
        expect(@redis_mock).to receive(:get).and_return(invalid_code)
        result = user_for_2fa_verification.verify_2fa_code(invalid_code)
        expect(result[:status]).to eq(:unauthorized)
        expect(result[:token]).to be_nil
        expect(result[:errors]).to include('Invalid 2FA code')
      end
    end

    context 'when Redis connection fails (fallback to DB)' do
      let!(:second_factor_code_db) { user_for_2fa_verification.create_second_factor_code(code: valid_code) }

      before do
        expect(@redis_mock).to receive(:get).and_raise(Redis::CannotConnectError)
        allow(user_for_2fa_verification).to receive(:generate_jwt).and_return('fake_jwt_token_db')
      end

      it 'returns token and ok status for valid code from DB' do
        result = user_for_2fa_verification.verify_2fa_code(valid_code)
        expect(result[:status]).to eq(:ok)
        expect(result[:token]).to eq('fake_jwt_token_db')
        expect(result[:errors]).to be_nil
        expect(user_for_2fa_verification.reload.second_factor_code).to be_nil
      end

      it 'returns unauthorized for invalid code from DB' do
        result = user_for_2fa_verification.verify_2fa_code(invalid_code)
        expect(result[:status]).to eq(:unauthorized)
        expect(result[:token]).to be_nil
        expect(result[:errors]).to include('Invalid 2FA code')
        expect(user_for_2fa_verification.reload.second_factor_code).to eq(second_factor_code_db)
      end
    end
  end

  describe '#generate_jwt' do
    it 'generates a valid JWT token' do
      expect(@redis_mock).to receive(:set).with(instance_of(String), 'active',
                                                ex: an_instance_of(Integer)).and_return(true)

      token = user.generate_jwt
      expect(token).to be_present
      decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
      expect(decoded_token[0]['user_id']).to eq(user.id)
      expect(decoded_token[0]['exp']).to be > Time.current.to_i
    end

    context 'when Redis connection fails' do
      before do
        expect(@redis_mock).to receive(:set).and_raise(StandardError, 'Redis error: Failed to cache JWT')
        allow(Rails.logger).to receive(:error)
      end

      it 'still returns a JWT token' do
        token = user.generate_jwt
        expect(token).to be_present
      end
    end
  end

  describe '#activate_with_code' do
    let!(:user_with_activation_code) { create(:user, active: false) }
    let!(:activation_code_record) { user_with_activation_code.create_activation_code(code: 'test_code') }

    it 'activates the user with a valid code' do
      expect(user_with_activation_code).not_to be_active
      result = user_with_activation_code.activate_with_code('test_code')
      user_with_activation_code.reload
      expect(user_with_activation_code).to be_active
      expect(result[:status]).to eq(:ok)
      expect(result[:message]).to eq('Account activated')
      expect(user_with_activation_code.activation_code).to be_nil
    end

    it 'does not activate the user with an invalid code' do
      expect(user_with_activation_code).not_to be_active
      result = user_with_activation_code.activate_with_code('wrong_code')
      user_with_activation_code.reload
      expect(user_with_activation_code).not_to be_active
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include('Invalid activation code')
      expect(user_with_activation_code.activation_code).to be_present
    end
  end

  describe '#verify_with_code' do
    let!(:user_with_verification_code) { create(:user, verified: false) }
    let!(:verification_code_record) { user_with_verification_code.create_verification_code(code: 'verify_code') }

    it 'verifies the user with a valid code' do
      expect(user_with_verification_code).not_to be_verified
      result = user_with_verification_code.verify_with_code('verify_code')
      user_with_verification_code.reload
      expect(user_with_verification_code).to be_verified
      expect(result[:status]).to eq(:ok)
      expect(result[:message]).to eq('Account verified')
      expect(user_with_verification_code.verification_code).to be_nil
    end

    it 'does not verify the user with an invalid code' do
      expect(user_with_verification_code).not_to be_verified
      result = user_with_verification_code.verify_with_code('wrong_verify_code')
      user_with_verification_code.reload
      expect(user_with_verification_code).not_to be_verified
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include('Invalid verification code')
      expect(user_with_verification_code.verification_code).to be_present
    end
  end

  describe '.request_password_reset' do
    let!(:reset_user) { create(:user) }

    before do
      allow(UserMailer).to receive_message_chain(:send_reset_code, :deliver_later).and_return(true)
      expect(@redis_mock).to receive(:set).with(instance_of(String), instance_of(String),
                                                ex: an_instance_of(Integer)).and_return(true)
      reset_user.reset_code&.destroy
    end

    it 'sends reset instructions if user exists' do
      result = User.request_password_reset(reset_user.mail)
      expect(result[:status]).to eq(:ok)
      expect(result[:message]).to eq('If an account with that email exists, we have sent password reset instructions.')
      expect(reset_user.reload.reset_code).to be_present
    end

    it 'still returns success message if user does not exist (for security)' do
      result = User.request_password_reset('nonexistent@example.com')
      expect(result[:status]).to eq(:ok)
      expect(result[:message]).to eq('If an account with that email exists, we have sent password reset instructions.')
    end

    context 'when Redis connection fails' do
      before do
        expect(@redis_mock).to receive(:set).and_raise(Redis::CannotConnectError)
        reset_user.reset_code&.destroy
      end

      it 'falls back to database and still sends reset instructions' do
        result = User.request_password_reset(reset_user.mail)
        expect(result[:status]).to eq(:ok)
        expect(reset_user.reload.reset_code).to be_present
      end
    end
  end

  describe '.reset_password_with_code' do
    let(:new_password) { 'NewSecurePass1!' }
    let(:valid_reset_code) { 'valid_reset_code' }
    let!(:user_for_reset) { create(:user, password: 'old_password') }

    context 'when reset code is in Redis' do
      before do
        expect(@redis_mock).to receive(:scan_each).with(match: 'user:*:reset_code').and_yield("user:#{user_for_reset.id}:reset_code")
        expect(@redis_mock).to receive(:get).with("user:#{user_for_reset.id}:reset_code").and_return(valid_reset_code)
        expect(@redis_mock).to receive(:del).with("user:#{user_for_reset.id}:reset_code").and_return(1)
        user_for_reset.reset_code&.destroy
        allow_any_instance_of(ResetCode).to receive(:destroy).and_return(true)
      end

      it 'resets password with valid code and destroys code' do
        result = User.reset_password_with_code(valid_reset_code, new_password, new_password)
        expect(result[:status]).to eq(:ok)
        expect(result[:message]).to eq('Password has been reset successfully.')
        expect(user_for_reset.reload).to be_authenticate(new_password)
      end
    end

    context 'when reset code is in database (Redis fails)' do
      let!(:reset_code_db) { user_for_reset.create_reset_code(code: valid_reset_code, expires_at: 1.hour.from_now) }
      before do
        expect(@redis_mock).to receive(:scan_each).and_raise(Redis::CannotConnectError)
      end

      it 'resets password with valid code from DB and destroys code' do
        result = User.reset_password_with_code(valid_reset_code, new_password, new_password)
        expect(result[:status]).to eq(:ok)
        expect(result[:message]).to eq('Password has been reset successfully.')
        expect(user_for_reset.reload).to be_authenticate(new_password)
        expect(user_for_reset.reset_code).to be_nil
      end
    end

    it 'returns unprocessable_entity for invalid or expired code' do
      result = User.reset_password_with_code('wrong_code', new_password, new_password)
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include('Invalid or expired reset code')
      expect(user_for_reset.reload).not_to be_authenticate(new_password)
    end

    it 'returns unprocessable_entity for password mismatch' do
      expect(@redis_mock).to receive(:scan_each).with(match: 'user:*:reset_code').and_return([])
      let!(:reset_code_db) { user_for_reset.create_reset_code(code: valid_reset_code, expires_at: 1.hour.from_now) }

      result = User.reset_password_with_code(valid_reset_code, new_password, 'mismatched_password')
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include("Password confirmation doesn't match Password")
      expect(user_for_reset.reload).not_to be_authenticate(new_password)
    end
  end

  describe '#blacklist_token' do
    let(:token_to_blacklist) { 'some_jwt_token_to_blacklist' }

    context 'when Redis is available' do
      before do
        expect(@redis_mock).to receive(:set).with(instance_of(String), 'blacklisted',
                                                  ex: an_instance_of(Integer)).and_return(true)
        allow(user.blacklisted_tokens).to receive(:create).and_return(double('BlacklistedToken',
                                                                             token: token_to_blacklist))
      end

      it 'blacklists the token in Redis and returns success' do
        result = user.blacklist_token(token_to_blacklist)
        expect(result[:status]).to eq(:ok)
        expect(result[:message]).to eq('Logged out')
        expect(user.blacklisted_tokens).to have_received(:create).once
      end
    end

    context 'when Redis connection fails' do
      before do
        expect(@redis_mock).to receive(:set).and_raise(Redis::CannotConnectError)
        expect(user.blacklisted_tokens).to receive(:create).with(token: token_to_blacklist).and_return(double(
                                                                                                         'BlacklistedToken', token: token_to_blacklist
                                                                                                       ))
      end

      it 'blacklists the token in database and returns success' do
        result = user.blacklist_token(token_to_blacklist)
        expect(result[:status]).to eq(:ok)
        expect(result[:message]).to eq('Logged out')
        expect(user.blacklisted_tokens).to have_received(:create).once
      end
    end
  end

  describe '.token_blacklisted?' do
    let(:test_token) { 'some_test_jwt' }

    context 'when Redis is available' do
      it 'returns true if token is blacklisted in Redis' do
        expect(@redis_mock).to receive(:scan_each).with(match: "user:*:jwt:#{test_token}").and_yield("user:#{user.id}:jwt:#{test_token}")
        expect(@redis_mock).to receive(:get).with("user:#{user.id}:jwt:#{test_token}").and_return('blacklisted')
        expect(User.token_blacklisted?(test_token)).to be true
      end

      it 'returns false if token is not blacklisted in Redis' do
        expect(@redis_mock).to receive(:scan_each).and_return([])
        expect(User.token_blacklisted?(test_token)).to be false
      end
    end

    context 'when Redis connection fails' do
      before do
        expect(@redis_mock).to receive(:scan_each).and_raise(Redis::CannotConnectError)
      end

      it 'returns true if token is blacklisted in database' do
        create(:blacklisted_token, token: test_token, owner: user)
        expect(User.token_blacklisted?(test_token)).to be true
      end

      it 'returns false if token is not blacklisted in database' do
        expect(User.token_blacklisted?(test_token)).to be false
      end
    end
  end

  describe '#accessible_by?' do
    it 'returns true if other_user is an admin' do
      expect(user.accessible_by?(admin_user)).to be true
    end

    it 'returns true if other_user is the same user' do
      expect(user.accessible_by?(user)).to be true
    end

    it 'returns false if other_user is a different regular user' do
      another_regular_user = create(:user, role: :regular)
      expect(user.accessible_by?(another_regular_user)).to be false
    end

    it 'returns false if other_user is nil' do
      expect(user.accessible_by?(nil)).to be false
    end
  end

  describe '#update_with_params' do
    context 'with valid parameters' do
      it 'updates the user attributes' do
        new_mail = 'new_mail@example.com'
        result = user.update_with_params(mail: new_mail)
        expect(result[:status]).to eq(:ok)
        expect(user.reload.mail).to eq(new_mail)
      end
    end

    context 'with invalid parameters' do
      it 'returns errors and unprocessable_entity status' do
        result = user.update_with_params(mail: nil)
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:errors]).to include("Mail can't be blank")
        expect(user.reload.mail).not_to be_nil
      end
    end
  end

  describe '#destroy_user' do
    let!(:user_to_destroy) { create(:user) }

    it 'destroys the user record' do
      expect { user_to_destroy.destroy_user }.to change(User, :count).by(-1)
      expect(User.find_by(id: user_to_destroy.id)).to be_nil
      result = user_to_destroy.destroy_user
      expect(result[:status]).to eq(:no_content)
    end
  end

  describe '#two_factor_enabled?' do
    it 'returns true if two factor is enabled in user settings' do
      user_settings = user.create_user_settings(two_factor_enabled: true)
      expect(user.two_factor_enabled?).to be true
    end

    it 'returns false if two factor is disabled in user settings' do
      user_settings = user.create_user_settings(two_factor_enabled: false)
      expect(user.two_factor_enabled?).to be false
    end

    it 'returns false if user settings do not exist' do
      user.user_settings.destroy if user.user_settings.present?
      expect(user.two_factor_enabled?).to be false
    end
  end

  describe '#update_user_location' do
    let!(:user_with_detail) { create(:user, :with_detail) }

    it 'updates user location if user_detail exists' do
      location_params = { country: 'Poland', city: 'Warsaw' }
      expect(user_with_detail.user_detail).to receive(:update_location).with(location_params).and_return({ status: :ok })

      result = user_with_detail.update_user_location(location_params)
      expect(result[:status]).to eq(:ok)
    end

    it 'returns error if user_detail does not exist' do
      user_without_detail = create(:user)
      user_without_detail.user_detail.destroy if user_without_detail.user_detail.present?

      location_params = { country: 'Poland', city: 'Warsaw' }
      result = user_without_detail.update_user_location(location_params)
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include('User details not found')
    end
  end

  describe '#update_user_details' do
    let!(:user_with_detail) { create(:user, :with_detail) }

    it 'updates user details if user_detail exists' do
      details_params = { first_name: 'Jane' }
      expect(user_with_detail.user_detail).to receive(:update_details).with(details_params).and_return({ status: :ok })

      result = user_with_detail.update_user_details(details_params)
      expect(result[:status]).to eq(:ok)
    end

    it 'returns error if user_detail does not exist' do
      user_without_detail = create(:user)
      user_without_detail.user_detail.destroy if user_without_detail.user_detail.present?

      details_params = { first_name: 'Jane' }
      result = user_without_detail.update_user_details(details_params)
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include('User details not found')
    end
  end

  describe '#update_user_entrepreneur_details' do
    let!(:user_with_detail) { create(:user, :with_detail) }

    it 'updates user entrepreneur details if user_detail exists' do
      entrepreneur_params = { business_name: 'Acme Corp' }
      expect(user_with_detail.user_detail).to receive(:update_entrepreneur_details).with(entrepreneur_params).and_return({ status: :ok })

      result = user_with_detail.update_user_entrepreneur_details(entrepreneur_params)
      expect(result[:status]).to eq(:ok)
    end

    it 'returns error if user_detail does not exist' do
      user_without_detail = create(:user)
      user_without_detail.user_detail.destroy if user_without_detail.user_detail.present?

      entrepreneur_params = { business_name: 'Acme Corp' }
      result = user_without_detail.update_user_entrepreneur_details(entrepreneur_params)
      expect(result[:status]).to eq(:unprocessable_entity)
      expect(result[:errors]).to include('User details not found')
    end
  end
end
