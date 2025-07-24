# frozen_string_literal: true

json.cache! ['order_show', @order.id, @order.updated_at, @order.items.maximum(:updated_at) || Time.current] do
  json.order do
    json.partial! 'api/v1/orders/order', order: @order
  end
end
