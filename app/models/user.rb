# frozen_string_literal: true

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

  def accessible_by?(other_user)
    other_user&.admin? || id == other_user&.id
  end

  def two_factor_enabled?
    user_settings&.two_factor_enabled
  end
end
