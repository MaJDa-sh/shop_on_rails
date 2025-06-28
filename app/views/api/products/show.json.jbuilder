json.extract! @product, :id, :name, :description, :price

json.product_photos_attributes @product.product_photos do |photo|
  json.id photo.id
  json.url rails_blob_url(photo.image)
end
