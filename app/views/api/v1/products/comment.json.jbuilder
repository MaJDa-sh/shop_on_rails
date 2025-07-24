# frozen_string_literal: true

json.message @message
json.comment do
  json.partial! 'api/v1/products/product_comment', product_comment: @comment
end
json.product do
  json.id @product.id
  json.comments_count @product.product_comments.count
end
