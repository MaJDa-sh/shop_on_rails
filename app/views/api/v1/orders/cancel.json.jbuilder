# frozen_string_literal: true

if @errors
  json.errors @errors
else
  json.message @message
  json.order do
    json.partial! 'api/v1/orders/order', order: @order
  end
end
