# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :product_photos, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :product_likes, dependent: :destroy
  has_many :product_rates, dependent: :destroy

  accepts_nested_attributes_for :product_photos, allow_destroy: true
end
