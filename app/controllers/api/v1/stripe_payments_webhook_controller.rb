# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles incoming webhooks from the Stripe payment gateway.
    #
    # This controller provides a public endpoint to receive asynchronous events
    # from Stripe, such as charge successes, failures, or refunds. It is responsible
    # for verifying the authenticity of these webhooks before processing them.
    class StripePaymentsWebhookController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/v1/stripe_payments_webhook/handle
      #
      # Receives and processes a webhook event from Stripe.
      #
      # This action validates the webhook's signature to ensure it originated from
      # Stripe and was not tampered with. If the signature is valid, the event
      # payload is passed to the Payment model for business logic processing.
      #
      # @return [void] Renders a status response:
      #   - `200 OK` on successful handling.
      #   - `400 Bad Request` if the payload is invalid or the signature is incorrect.
      # @see Payment.handle_stripe_event
      def handle
        payload = request.body.read
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]
        event = nil

        begin
          event = Stripe::Webhook.construct_event(
            payload, sig_header, endpoint_secret
          )
        rescue JSON::ParserError
          @errors = ['Invalid payload']
          @status = :bad_request
          return
        rescue Stripe::SignatureVerificationError
          @errors = ['Signature verification failed']
          @status = :bad_request
          return
        end

        Payment.handle_stripe_event(event)

        @message = 'Webhook handled successfully'
        @status = :ok
      end
    end
  end
end
