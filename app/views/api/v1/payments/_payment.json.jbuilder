# frozen_string_literal: true

json.cache! ['payment_partial', payment.id, payment.updated_at, payment.order&.updated_at] do
  json.id payment.id
  json.order_id payment.order_id
  json.amount payment.amount
  json.currency payment.currency
  json.status payment.status
  json.payment_method payment.payment_method
  json.created_at payment.created_at
  json.updated_at payment.updated_at

  if payment.order.present?
    json.order do
      json.id payment.order.id
      json.total_amount payment.order.total_amount
      json.status payment.order.status
    end
  end
end
