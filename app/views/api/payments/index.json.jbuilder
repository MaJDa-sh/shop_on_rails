# frozen_string_literal: true

if @errors
  json.errors @errors
else
  json.array! @payments, partial: 'api/v1/payments/payment', as: :payment
end
