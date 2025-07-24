# frozen_string_literal: true

json.message 'Product created successfully.'
json.product do
  json.partial! 'api/v1/products/product', product: @product
end
