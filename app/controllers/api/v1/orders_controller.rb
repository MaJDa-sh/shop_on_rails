# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    # Handles operations for Order resources via the API.
    #
    # This controller provides endpoints to manage user orders, including listing,
    # creating from a cart, viewing details, and modifying status.
    # It enforces authentication and role-based authorization for secure access.
    # Responses are handled by Jbuilder templates.
    class OrdersController < ApplicationController
      before_action :authenticate_user!
      load_and_authorize_resource exccept: [:me]

      # GET /api/v1/orders
      #
      # Retrieves a list of orders.
      #
      # This endpoint returns a list of orders. If the authenticated user is an admin,
      # it returns all orders. Otherwise, it returns only the orders belonging to the
      # current user.
      def index
        @orders = Order.accessible_by(current_ability).includes(:user, :items).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/orders/me
      #
      # Retrieves the orders for the currently authenticated user.
      #
      # This endpoint provides a convenient way for a user to fetch their own
      # order history without needing to know their user ID.
      def me
        @orders = current_user.orders.includes(:items).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/orders/:id
      #
      # Retrieves a single order by ID.
      #
      # This endpoint returns the details of a specific order, including its status,
      # items, and total amount. It is accessible only to the user who owns the
      # order or to an admin.
      def show
        @status = :ok
      end

      # POST /api/v1/orders
      #
      # Creates a new order from the user's cart.
      #
      # This endpoint creates a new order for the authenticated user based on the
      # items currently in their cart. The cart is cleared upon successful
      # order creation. This action does not require any parameters in the request body.
      def create
        cart_items = current_user.cart_items
        if cart_items.empty?
          @errors = ['Your cart is empty.']
          @status = :unprocessable_entity
          return
        end

        @order.user = current_user
        @order.status = :pending
        @order.payment_status = :unpaid

        ActiveRecord::Base.transaction do
          @order.save!
          cart_items.update_all(order_id: @order.id)
          @order.reload.save!
        end

        @status = :created
      rescue ActiveRecord::RecordInvalid => e
        @errors = e.record.errors.full_messages
        @status = :unprocessable_entity
      end

      # PATCH/PUT /api/v1/orders/:id
      #
      # Updates an existing order.
      #
      # This endpoint allows an admin to update an order's attributes, such as its
      # status or payment status. It is restricted to admin users only.
      #
      # @param [Hash] order_params Parameters for updating an order.
      # @option order_params [String] :status The new order status (e.g., "shipped", "delivered").
      # @option order_params [String] :payment_status The new payment status (e.g., "paid").
      def update
        result = @order.update_with_params(order_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/orders/:id/cancel
      #
      # Cancels an existing order.
      #
      # This endpoint allows a user to cancel their own order, or an admin to cancel
      # any order. An order can only be cancelled if it is in a 'pending' or
      # 'processing' state.
      def cancel
        result = @order.cancel_order
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # DELETE /api/v1/orders/:id
      #
      # Deletes an order permanently.
      #
      # This endpoint removes an order and its associated data from the database.
      # This action is restricted to admin users only.
      def destroy
        result = @order.destroy_order
        @status = result[:status]
      end

      private

      # Defines permitted parameters for updating an order.
      #
      # @return [ActionController::Parameters] Permitted parameters for the order.
      def order_params
        params.require(:order).permit(:status, :payment_status)
      end
    end
  end
end
