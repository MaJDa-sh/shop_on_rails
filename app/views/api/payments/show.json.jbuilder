# frozen_string_literal: true

if @errors
  json.errors @errors
else
  json.payment do
    json.partial! 'api/v1/payments/payment', payment: @payment
  end
end
