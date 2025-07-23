# frozen_string_literal: true

if @product&.persisted?
  json.extract! @product, :id, :name, :price, :description, :created_at, :updated_at
  json.product_photos @product.product_photos do |photo|
    json.id photo.id
    json.url rails_blob_url(photo.image) if photo.image.attached?
  end
else
  json.errors @errors
end
json.status @status
