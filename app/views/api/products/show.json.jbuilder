json.extract! @product, :id, :name, :description, :price
json.photos @product.product_photos.map { |photo| url_for(photo) }
