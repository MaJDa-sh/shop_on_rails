# frozen_string_literal: true

require 'jwt'
require 'redis'

class User < ApplicationRecord
  enum :role, %w[regular moderator admin]
  alias user? regular?

  has_secure_password

  has_one :user_detail, dependent: :destroy
  has_one :user_settings, dependent: :destroy
  has_one :activation_code, dependent: :destroy
  has_one :verification_code, dependent: :destroy
  has_one :second_factor_code, dependent: :destroy
  has_one :reset_code, dependent: :destroy
  has_many :user_actions, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :blacklisted_tokens, foreign_key: :owner_id, dependent: :destroy
  has_many :comments, dependent: :destroy

  has_many :cart_items, -> { where(order_id: nil) }, class_name: 'Item', dependent: :destroy

  accepts_nested_attributes_for :user_detail

  validates :mail, presence: true, uniqueness: true
  validates :phone, uniqueness: true, allow_nil: true
  validates :password_digest, presence: true

  def self.redis
    @redis ||= Redis.current
  end

  def self.authenticate_user(email, password)
    user = find_by(mail: email)
    unless user&.authenticate(password)
      return { user: nil, errors: ['Invalid email or password'], status: :unauthorized }
    end

    if user.two_factor_enabled?
      user.generate_2fa_code
      { user: user, message: '2FA code sent to your email', status: :accepted }
    else
      token = user.generate_jwt
      { user: user, token: token, status: :ok }
    end
  end

  def generate_2fa_code
    code = SecureRandom.hex(8)
    redis_key = "user:#{id}:2fa_code"
    begin
      self.class.redis.set(redis_key, code, ex: 15.minutes.to_i)
      second_factor_code&.destroy
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: #{e.message}")
      second_factor_code&.destroy
      create_second_factor_code(code: code)
      code = second_factor_code.code
    end
    UserMailer.dial_2fa_code(self, code).deliver_later
  end

  def verify_2fa_code(code)
    redis_key = "user:#{id}:2fa_code"
    begin
      stored_code = self.class.redis.get(redis_key)
      if stored_code == code
        self.class.redis.del(redis_key)
        second_factor_code&.destroy
        return { token: generate_jwt, status: :ok }
      end
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: #{e.message}")
    end
    if second_factor_code&.code == code
      second_factor_code.destroy
      { token: generate_jwt, status: :ok }
    else
      { errors: ['Invalid 2FA code'], status: :unauthorized }
    end
  end

  def generate_jwt
    payload = { user_id: id, exp: 24.hours.from_now.to_i }
    token = JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
    redis_key = "user:#{id}:jwt:#{token}"
    begin
      self.class.redis.set(redis_key, 'active',
                           ex: 24.hours.to_i)
    rescue StandardError
      Rails.logger.error('Redis error: Failed to cache JWT')
    end
    token
  end

  def activate_with_code(activation_code)
    if self.activation_code&.code == activation_code
      update(active: true)
      self.activation_code.destroy
      { message: 'Account activated', status: :ok }
    else
      { errors: ['Invalid activation code'], status: :unprocessable_entity }
    end
  end

  def verify_with_code(verification_code)
    if self.verification_code&.code == verification_code
      update(verified: true)
      self.verification_code.destroy
      { message: 'Account verified', status: :ok }
    else
      { errors: ['Invalid verification code'], status: :unprocessable_entity }
    end
  end

  def self.request_password_reset(email)
    user = find_by(mail: email)
    if user
      code = SecureRandom.hex(16)
      redis_key = "user:#{user.id}:reset_code"
      begin
        redis.set(redis_key, code, ex: 2.hours.to_i)
        UserMailer.dial_reset_code(user, code).deliver_later
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error: #{e.message}")
      end
      user.reset_code&.destroy
      user.create_reset_code(code: code, expires_at: 2.hours.from_now)
      UserMailer.dial_reset_code(user, code).deliver_later
    end
    { message: 'If an account with that email exists, we have sent password reset instructions.', status: :ok }
  end

  def self.reset_password_with_code(reset_code, password, password_confirmation)
    user_id = nil
    begin
      redis.scan_each(match: 'user:*:reset_code') do |key|
        if redis.get(key) == reset_code
          user_id = key.split(':')[1].to_i
          break
        end
      end
      if user_id
        user = find_by(id: user_id)
        unless user && user.update(password: password, password_confirmation: password_confirmation)
          return { errors: user&.errors&.full_messages || ['User not found'], status: :unprocessable_entity }
        end

        redis.del("user:#{user_id}:reset_code")
        user.reset_code&.destroy
        return { message: 'Password has been reset successfully.', status: :ok }

      end
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: #{e.message}")
    end

    reset = ResetCode.find_by(code: reset_code)
    if reset && reset.expires_at > Time.current
      user = reset.user
      if user.update(password: password, password_confirmation: password_confirmation)
        reset.destroy
        { message: 'Password has been reset successfully.', status: :ok }
      else
        { errors: user.errors.full_messages, status: :unprocessable_entity }
      end
    else
      { errors: ['Invalid or expired reset code'], status: :unprocessable_entity }
    end
  end

  def blacklist_token(token)
    redis_key = "user:#{id}:jwt:#{token}"
    begin
      self.class.redis.set(redis_key, 'blacklisted', ex: 24.hours.to_i)
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: #{e.message}")
      blacklisted_tokens.create(token: token)
    end
    blacklisted_tokens.create(token: token)
    { message: 'Logged out', status: :ok }
  rescue StandardError
    { errors: ['Failed to blacklist token'], status: :unprocessable_entity }
  end

  def self.token_blacklisted?(token)
    begin
      redis_key = redis.scan_each(match: "user:*:jwt:#{token}").find { |key| redis.get(key) == 'blacklisted' }
      return true if redis_key
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: #{e.message}")
    end
    BlacklistedToken.exists?(token: token)
  end

  def accessible_by?(other_user)
    other_user&.admin? || id == other_user&.id
  end

  def update_with_params(params)
    if update(params)
      { status: :ok }
    else
      { errors: errors.full_messages, status: :unprocessable_entity }
    end
  end

  def destroy_user
    destroy
    { status: :no_content }
  end

  def two_factor_enabled?
    user_settings&.two_factor_enabled
  end

  def update_user_location(location_params)
    return { errors: ['User details not found'], status: :unprocessable_entity } unless user_detail

    user_detail.update_location(location_params)
  end

  def update_user_details(details_params)
    return { errors: ['User details not found'], status: :unprocessable_entity } unless user_detail

    user_detail.update_details(details_params)
  end

  def update_user_entrepreneur_details(entrepreneur_params)
    return { errors: ['User details not found'], status: :unprocessable_entity } unless user_detail

    user_detail.update_entrepreneur_details(entrepreneur_params)
  end

  def add_product_to_cart(product, quantity)
    raise ActiveRecord::RecordNotFound, 'Product not found' unless product
    raise ArgumentError, 'Quantity must be greater than 0' unless quantity.to_i > 0

    cart_item = cart_items.find_or_initialize_by(product: product)
    cart_item.quantity = (cart_item.quantity || 0) + quantity.to_i
    cart_item.price_at_purchase = product.price
    cart_item.save!
  end

  def remove_product_from_cart(item_id, quantity_to_remove = nil)
    item = cart_items.find_by(id: item_id)
    raise ActiveRecord::RecordNotFound, 'Item not found in cart' unless item

    quantity_to_remove = quantity_to_remove.to_i if quantity_to_remove.present?

    if quantity_to_remove.present? && quantity_to_remove > 0 && quantity_to_remove < item.quantity
      item.quantity -= quantity_to_remove
      item.save!
    else
      item.destroy!
    end
  end

  def like_product(product)
    raise ActiveRecord::RecordNotFound, 'Product not found' unless product
    if ProductLike.exists?(user: self, product: product)
      raise ActiveRecord::RecordInvalid, 'You have already liked this product'
    end

    ProductLike.create!(user: self, product: product)
    true
  end

  def rate_product(product, rating, comment = nil)
    raise ActiveRecord::RecordNotFound, 'Product not found' unless product
    unless rating.present? && (1..5).include?(rating.to_i)
      raise ArgumentError, 'Rating must be an integer between 1 and 5'
    end

    product_rate = ProductRate.find_or_initialize_by(user: self, product: product)
    product_rate.rating = rating.to_i
    product_rate.comment = comment

    product_rate.save!
    true
  end

  def add_comment_to_product(product, content, parent_id = nil)
    raise ActiveRecord::RecordNotFound, 'Product not found' unless product
    raise ArgumentError, 'Comment content cannot be empty' unless content.present?

    parent_comment = Comment.find_by(id: parent_id) if parent_id.present?
    raise ActiveRecord::RecordNotFound, 'Parent comment not found' if parent_id.present? && parent_comment.nil?

    comment = Comment.new(user: self, product: product, content: content, parent: parent_comment)
    comment.save!
    comment
  end

  def clear_user_cart
    cart_items.destroy_all!
  end

  private

  def redis
    self.class.redis
  end
end
