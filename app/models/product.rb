class Product < ApplicationRecord
  has_many :product_photos, dependent: :destroy
  accepts_nested_attributes_for :product_photos, allow_destroy: true

  after_save :assign_photos
  attr_accessor :product_photo_ids

  private

  def assign_photos
    Rails.logger.info "Assigning photos: #{product_photo_ids.inspect}"
    return if product_photo_ids.blank?

    ids = Array(product_photo_ids).reject(&:blank?)
    return if ids.empty?

    ProductPhoto.where(id: ids).update_all(product_id: id)
  end
end
