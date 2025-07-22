# frozen_string_literal: true

class User < ApplicationRecord
  enum role: { regular: 'regular', moderator: 'moderator', admin: 'admin' }
  alias user? regular?

  validates :mail, presence: true, uniqueness: true
  validates :phone, uniqueness: true, allow_nil: true
  validates :password_digest, presence: true
  has_secure_password

  has_one :user_detail, dependent: :destroy

  has_one :user_settings, dependent: :destroy

  has_one :activation_code, dependent: :destroy
  has_one :verification_code, dependent: :destroy
  has_one :second_factor_code, dependent: :destroy
  has_one :reset_code, dependent: :destroy

  has_many :user_devices, dependent: :destroy
  has_many :user_actions, dependent: :destroy

  has_many :blacklisted_tokens, foreign_key: :owner_id, dependent: :destroy

  def create_activation_code(code); end

  def create_verification_code(code); end
end
