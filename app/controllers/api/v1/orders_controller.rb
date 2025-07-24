# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles operations for Order resources via the API.
    #
    # This controller provides endpoints to manage user orders, including listing,
    # creating from a cart, viewing details, and modifying status.
    # It enforces authentication and role-based authorization for secure access.
    class OrdersController < ApplicationController
      before_action :authenticate_user!
      load_and_authorize_resource except: [:me]

      # GET /api/v1/orders
      #
      # Retrieves a list of orders based on user role.
      #
      # Admins receive a list of all orders. Regular users receive a list
      # of their own orders only. The list is ordered by creation date.
      #
      # @return [void] Sets `@orders` for the Jbuilder view, rendering with
      #   a status of `:ok` (200).
      def index
        @orders = Order.accessible_by(current_ability).includes(:user, :items).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/orders/me
      #
      # Retrieves all orders for the currently authenticated user.
      #
      # A convenience endpoint for users to fetch their own order history.
      #
      # @return [void] Sets `@orders` for the Jbuilder view, rendering with
      #   a status of `:ok` (200).
      def me
        @orders = current_user.orders.includes(:items).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/orders/:id
      #
      # Retrieves a single order by its ID.
      #
      # The `@order` instance variable is loaded and authorized automatically
      # by CanCanCan's `load_and_authorize_resource`.
      #
      # @return [void] Renders the `@order` using the Jbuilder view with a
      #   status of `:ok` (200).
      def show
        @status = :ok
      end

      # POST /api/v1/orders
      #
      # Creates a new order from the items in the user's current cart.
      #
      # This action is transactional. It creates an `Order` record, assigns all
      # of the user's cart items to it, and clears the cart. No request body is needed.
      #
      # @return [void] On success, sets `@order` and renders with `:created` (201).
      #   On failure (e.g., empty cart), sets `@errors` and renders with
      #   `:unprocessable_entity` (422).
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
      # Updates an existing order (Admin only).
      #
      # Allows an admin to update attributes like `status` or `payment_status`.
      # The `@order` is loaded automatically by `load_and_authorize_resource`.
      #
      # @param [Hash] :order The parameters for the order.
      # @option order [String] :status The new order status (e.g., "shipped").
      # @option order [String] :payment_status The new payment status (e.g., "paid").
      #
      # @return [void] Sets `@errors` on failure and renders with a status of
      #   `:ok` (200) or `:unprocessable_entity` (422).
      # @see Order#update_with_params
      def update
        result = @order.update_with_params(order_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/orders/:id/cancel
      #
      # Cancels an order.
      #
      # Allows a user to cancel their own order or an admin to cancel any order,
      # provided it is in a cancellable state (e.g., 'pending').
      # The `@order` is loaded automatically by `load_and_authorize_resource`.
      #
      # @return [void] Sets `@message` or `@errors` and renders with an appropriate status.
      # @see Order#cancel_order
      def cancel
        result = @order.cancel_order
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # DELETE /api/v1/orders/:id
      #
      # Deletes an order permanently (Admin only).
      #
      # The `@order` is loaded automatically by `load_and_authorize_resource`.
      #
      # @return [void] Renders with a status of `:no_content` (204) on success.
      # @see Order#destroy_order
      def destroy
        result = @order.destroy_order
        @status = result[:status]
      end

      private

      # Defines permitted parameters for updating an order.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def order_params
        params.require(:order).permit(:status, :payment_status)
      end
    end
  end
end
