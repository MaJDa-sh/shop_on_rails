# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :product_photos, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :orders

  accepts_nested_attributes_for :product_photos, allow_destroy: true

  after_save :assign_photos
  after_commit :clear_cache, on: %i[create update destroy]
  attr_accessor :product_photo_ids

  def self.cached_find_all(page = 1)
    cache_key = ['products', page, Product.maximum(:updated_at).to_i]

    Rails.cache.fetch(cache_key, expires_in: 12.minute) do
      includes(:product_photos, :product_likes, :product_rates, :comments)
        .page(page).per(25).to_a
    end
  end

  def self.cached_find(id)
    product = find_by(id: id)
    return nil unless product

    cache_key = [product, 'details']

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      product
    end
  end

  private

  def assign_photos
    return if product_photo_ids.blank?

    ids = Array(product_photo_ids).reject(&:blank?)
    ProductPhoto.where(id: ids).update_all(product_id: id)
  end

  def clear_cache
    self.class.redis.del("product:#{id}")

    keys = self.class.redis.keys('products:page:*')
    self.class.redis.del(keys) if keys.any?
  rescue Redis::CannotConnectError => e
    Rails.logger.error("Redis cache clear error: #{e.message}")
  end

  def self.redis
    @redis ||= Redis.current
  end
end
