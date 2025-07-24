# frozen_string_literal: true

json.message 'Order created successfully.'
json.order do
  json.partial! 'api/v1/orders/order', order: @order
end
