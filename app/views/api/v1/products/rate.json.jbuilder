# frozen_string_literal: true

json.message @message
json.product do
  json.id @product.id
  json.average_rating @product.average_rating
  json.ratings_count @product.product_ratings.count if @product.respond_to?(:product_ratings)
end
