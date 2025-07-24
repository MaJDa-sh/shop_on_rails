# frozen_string_literal: true

json.array! @products do |product|
  json.cache! product do
    json.partial! 'api/v1/products/product', product: product
  end
end
