# frozen_string_literal: true

json.cache! ['product_show', @product.id, @product.updated_at] do
  json.product do
    json.partial! 'api/v1/products/product', product: @product
    json.likes @product.product_likes do |like|
      json.partial! 'api/v1/products/product_like', product_like: like
    end

    json.comments @product.product_comments.where(parent_id: nil) do |comment|
      json.partial! 'api/v1/products/product_comment', product_comment: comment
    end
  end
end
