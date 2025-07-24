# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles operations for Payment resources via the API.
    #
    # This controller provides endpoints to create and view payments associated with orders.
    # It integrates with the Payment model, which handles interaction with the
    # Stripe payment gateway. Access is restricted based on user ownership and roles.
    class PaymentsController < ApplicationController
      before_action :authenticate_user!
      load_and_authorize_resource

      # GET /api/v1/payments
      #
      # Retrieves a list of all payments (Admin only).
      #
      # This endpoint is restricted to admin users and returns a comprehensive list
      # of all payment transactions in the system, ordered by creation date.
      #
      # @return [void] Sets `@payments` for the Jbuilder view, rendering with
      #   a status of `:ok` (200).
      def index
        @payments = Payment.includes(:order).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/payments/:id
      #
      # Retrieves a single payment by its ID.
      #
      # The `@payment` instance variable is loaded and authorized automatically
      # by CanCanCan's `load_and_authorize_resource`. Accessible only to the
      # user who owns the associated order or to an admin.
      #
      # @return [void] Renders the `@payment` using the Jbuilder view with a
      #   status of `:ok` (200).
      def show
        @status = :ok
      end

      # POST /api/v1/payments
      #
      # Creates a new payment for a specific order using a Stripe token.
      #
      # This action validates that the order belongs to the current user and has not
      # been paid for. It then attempts to create a Stripe charge via a callback
      # in the Payment model.
      #
      # @param [Hash] :payment The parameters for the payment.
      # @option payment [Integer] :order_id The ID of the order to be paid.
      # @option payment [String] :stripe_token The single-use token from Stripe.
      #
      # @return [void] On success, sets `@payment` and renders with `:created` (201).
      #   On failure, sets `@errors` and renders with `:not_found` (404) or
      #   `:unprocessable_entity` (422).
      def create
        result = current_user.pay_for_order(
          order_id: payment_params[:order_id],
          stripe_token: payment_params[:stripe_token]
        )

        if result[:success]
          @payment = result[:payment]
          @status = :created
        else
          @errors = result[:errors]
          @status = :unprocessable_entity
        end
      end

      private

      # Defines permitted parameters for creating a payment.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def payment_params
        params.require(:payment).permit(:order_id, :stripe_token)
      end
    end
  end
end
