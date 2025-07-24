# frozen_string_literal: true

json.cache! @product do
  response.status = @status || :ok

  json.extract! @product, :id, :name, :price, :description

  json.photos @product.product_photos do |photo|
    json.id photo.id
    json.image_url photo.image_url
  end
end
