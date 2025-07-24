# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    # Handles operations for Payment resources via the API.
    #
    # This controller provides endpoints to create and view payments associated with orders.
    # It integrates with the Payment model, which handles the interaction with the
    # Stripe payment gateway. Access is restricted based on user ownership and roles.
    # Responses are handled by Jbuilder templates.
    class PaymentsController < ApplicationController
      before_action :authenticate_user!
      load_and_authorize_resource

      # GET /api/v1/payments
      #
      # Retrieves a list of all payments.
      #
      # This endpoint is restricted to admin users and returns a comprehensive list
      # of all payment transactions in the system.
      def index
        @payments = Payment.includes(:order).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/payments/:id
      #
      # Retrieves a single payment by ID.
      #
      # This endpoint returns the details of a specific payment. It is accessible only
      # to the user who owns the associated order or to an admin.
      def show
        @status = :ok
      end

      # POST /api/v1/payments
      #
      # Creates a new payment for a specific order.
      #
      # This endpoint initiates a payment process for an order. It requires an `order_id`
      # and a `stripe_token` (obtained from a client-side Stripe integration). The controller
      # verifies ownership and order status before attempting to create the payment, which
      # triggers a charge via the Stripe API in the Payment model.
      #
      # @param [Hash] payment_params Parameters for creating a payment.
      # @option payment_params [Integer] :order_id The ID of the order to pay for.
      # @option payment_params [String] :stripe_token The single-use token from Stripe.
      def create
        order = current_user.orders.find_by(id: payment_params[:order_id])

        if order.nil?
          @errors = ['order not found or does not belong to the user']
          @status = :not_found
          return
        end

        if order.paid?
          @errors = ['this order has already been paid for']
          @status = :unprocessable_entity
          return
        end

        @payment = Payment.new(
          order: order,
          amount: order.total_amount,
          stripe_token: payment_params[:stripe_token],
          payment_method: 'stripe'
        )

        if @payment.save
          if @payment.completed?
            order.mark_as_paid!
            @status = :created
          else
            @errors = [@payment.error_message]
            @status = :unprocessable_entity
          end
        else
          @errors = @payment.errors.full_messages
          @status = :unprocessable_entity
        end
      end

      private

      # Defines permitted parameters for creating a payment.
      #
      # @return [ActionController::Parameters] Permitted parameters for the payment.
      def payment_params
        params.require(:payment).permit(:order_id, :stripe_token)
      end
    end
  end
end
