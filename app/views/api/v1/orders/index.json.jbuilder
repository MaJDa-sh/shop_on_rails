# frozen_string_literal: true

if @errors
  json.errors @errors
else
  json.array! @orders, partial: 'api/v1/orders/order', as: :order
end
