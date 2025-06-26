class Product < ApplicationRecord
  has_many :product_photos, dependent: :destroy
  accepts_nested_attributes_for :product_photos, allow_destroy: true
end
