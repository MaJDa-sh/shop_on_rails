# frozen_string_literal: true

if @errors.blank?
  json.message 'Payment initiated successfully.'
  json.payment do
    json.partial! 'api/v1/payments/payment', payment: @payment
  end
else
  json.errors @errors
end
