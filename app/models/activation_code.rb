# frozen_string_literal: true

class ActivationCode < ApplicationRecord
  belongs_to :user

  validates :code, presence: true, uniqueness: true
  validates :expires_at, presence: true
end
