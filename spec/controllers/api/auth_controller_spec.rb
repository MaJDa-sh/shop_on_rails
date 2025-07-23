# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AuthController, type: :controller do
  let(:user) { create(:user, password: 'SecurePassword123!', password_confirmation: 'SecurePassword123!') }
  let(:redis) { Redis.current }

  before do
    allow(UserMailer).to receive_message_chain(:send_reset_code, :deliver_later).and_return(true)
  end

  describe 'POST #request_reset' do
    context 'when user exists' do
      it 'sends reset instructions and renders success response' do
        post :request_reset, params: { mail: user.mail }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['message']).to eq('If an account with that email exists, we have sent password reset instructions.')
        expect(user.reload.reset_code).to be_present
        expect(redis.get("user:#{user.id}:reset_code")).to be_present
      end
    end

    context 'when user does not exist' do
      it 'renders success response to prevent email enumeration' do
        post :request_reset, params: { mail: 'nonexistent@example.com' }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['message']).to eq('If an account with that email exists, we have sent password reset instructions.')
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow(Redis.current).to receive(:set).and_raise(Redis::CannotConnectError)
      end

      it 'falls back to database and renders success response' do
        post :request_reset, params: { mail: user.mail }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['message']).to eq('If an account with that email exists, we have sent password reset instructions.')
        expect(user.reload.reset_code).to be_present
      end
    end
  end

  describe 'PATCH #confirm_reset' do
    let(:valid_reset_code) { SecureRandom.hex(16) }
    let(:new_password) { 'NewSecurePass1!' }

    context 'when reset code is valid in Redis' do
      before do
        redis.set("user:#{user.id}:reset_code", valid_reset_code, ex: 2.hours.to_i)
        user.create_reset_code(code: valid_reset_code, expires_at: 2.hours.from_now)
      end

      it 'resets password and renders success response' do
        patch :confirm_reset, params: {
          reset_code: valid_reset_code,
          password: new_password,
          password_confirmation: new_password
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['message']).to eq('Password has been reset successfully.')
        expect(user.reload.authenticate(new_password)).to be_truthy
        expect(redis.get("user:#{user.id}:reset_code")).to be_nil
        expect(user.reload.reset_code).to be_nil
      end
    end

    context 'when reset code is valid in database (Redis fails)' do
      before do
        user.create_reset_code(code: valid_reset_code, expires_at: 2.hours.from_now)
        allow(Redis.current).to receive(:scan_each).and_raise(Redis::CannotConnectError)
      end

      it 'resets password and renders success response' do
        patch :confirm_reset, params: {
          reset_code: valid_reset_code,
          password: new_password,
          password_confirmation: new_password
        }, as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['message']).to eq('Password has been reset successfully.')
        expect(user.reload.authenticate(new_password)).to be_truthy
        expect(user.reload.reset_code).to be_nil
      end
    end

    context 'when reset code is invalid' do
      it 'renders unprocessable_entity with error' do
        patch :confirm_reset, params: {
          reset_code: 'invalid_code',
          password: new_password,
          password_confirmation: new_password
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('unprocessable_entity')
        expect(json['errors']).to include('Invalid or expired reset code')
        expect(user.reload.authenticate(new_password)).to be_falsey
      end
    end

    context 'when password confirmation does not match' do
      before do
        redis.set("user:#{user.id}:reset_code", valid_reset_code, ex: 2.hours.to_i)
        user.create_reset_code(code: valid_reset_code, expires_at: 2.hours.from_now)
      end

      it 'renders unprocessable_entity with error' do
        patch :confirm_reset, params: {
          reset_code: valid_reset_code,
          password: new_password,
          password_confirmation: 'mismatched_password'
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('unprocessable_entity')
        expect(json['errors']).to include("Password confirmation doesn't match Password")
        expect(user.reload.authenticate(new_password)).to be_falsey
      end
    end

    context 'when reset code is expired' do
      before do
        user.create_reset_code(code: valid_reset_code, expires_at: 1.hour.ago)
        redis.set("user:#{user.id}:reset_code", valid_reset_code, ex: 2.hours.to_i)
      end

      it 'renders unprocessable_entity with error' do
        patch :confirm_reset, params: {
          reset_code: valid_reset_code,
          password: new_password,
          password_confirmation: new_password
        }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('unprocessable_entity')
        expect(json['errors']).to include('Invalid or expired reset code')
        expect(user.reload.authenticate(new_password)).to be_falsey
      end
    end
  end
end
