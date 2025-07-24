# frozen_string_literal: true

json.cache! ['products_index', @products.map(&:id).sort, @products.maximum(:updated_at) || Time.current,
             params[:page]] do
  json.products @products do |product|
    json.partial! 'api/v1/products/product', product: product
  end

  json.meta do
    json.current_page @products.current_page
    json.next_page @products.next_page
    json.prev_page @products.prev_page
    json.total_pages @products.total_pages
    json.total_count @products.total_count
  end
end
