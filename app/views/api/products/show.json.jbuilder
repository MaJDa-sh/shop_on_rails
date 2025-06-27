json.extract! @product, :id, :name, :description, :price

json.product_photos_attributes @product.product_photos do |photo|
  json.id photo.id
  json.url url_for(photo.image)
end
