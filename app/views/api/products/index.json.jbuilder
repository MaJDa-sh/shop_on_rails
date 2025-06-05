json.array! @products do |product|
  json.extract! product, :id, :name
  json.photos product.photos.map { |photo| photo.url }
end
