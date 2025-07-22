# frozen_string_literal: true

class ProductPhoto < ApplicationRecord
  belongs_to :product, optional: true
  has_one_attached :image
end
