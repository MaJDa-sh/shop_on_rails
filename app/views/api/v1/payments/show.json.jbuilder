# frozen_string_literal: true

json.cache! ['payment_show', @payment.id, @payment.updated_at, @payment.order&.updated_at] do
  json.payment do
    json.partial! 'api/v1/payments/payment', payment: @payment
  end
end
