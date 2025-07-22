# frozen_string_literal: true

class UserDetail < ApplicationRecord
  belongs_to :user
  has_many :locations, dependent: :destroy
  has_one :entrepreneur_detail, dependent: :destroy

  validates :name, presence: true
end
