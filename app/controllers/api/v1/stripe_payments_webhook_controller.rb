# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    class StripePaymentsWebhookController < ApplicationController
      skip_before_action :verify_authenticity_token

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
          @errors = ['invalid payload']
          @status = :bad_request
          return
        rescue Stripe::SignatureVerificationError
          @errors = ['signature verification failed']
          @status = :bad_request
          return
        end

        Payment.handle_stripe_event(event)

        @message = 'webhook handled successfully'
        @status = :ok
      end
    end
  end
end
