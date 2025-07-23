# frozen_string_literal: true

module Api
  module V1
    # Handles shopping cart operations for authenticated users via the API.
    #
    # This controller provides endpoints for viewing, adding, removing, and
    # clearing items in the user's shopping cart. The cart is represented
    # by `Item` records directly associated with the user, not yet part of an `Order`.
    class CartController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/cart/me
      #
      # Displays the current authenticated user's shopping cart contents.
      #
      # The cart is dynamically composed of `Item` records associated with the user
      # that do not yet belong to a confirmed `Order`. The response includes
      # the total amount and item count, along with details for each item.
      #
      # @return [JSON] A JSON object representing the user's cart, including
      #                `total_amount`, `items_count`, and an array of `items`.
      def me
        @cart_items = current_user.cart_items.includes(:product)

        @total_amount = @cart_items.sum { |item| item.quantity * item.price_at_purchase }
        @items_count = @cart_items.sum(:quantity)
        @status = :ok
      end

      # POST /api/v1/cart/add
      #
      # Adds a specified quantity of a product to the authenticated user's shopping cart.
      #
      # If the product already exists in the cart, its quantity is updated.
      # If the product is new to the cart, a new cart item is created.
      #
      # @param [Integer] :product_id The ID of the product to add.
      # @param [Integer] :quantity The quantity of the product to add. Must be greater than 0.
      # @return [HTTP 204 No Content] On successful addition.
      # @raise [ActiveRecord::RecordNotFound] If the product is not found (handled by User model).
      # @raise [ArgumentError] If the quantity is not greater than 0 (handled by User model).
      # @raise [ActiveRecord::RecordInvalid] If cart item validation fails (handled by User model).
      def add
        product = Product.find_by(id: add_params[:product_id]) # Nadal szukamy produktu tutaj, aby przekazać obiekt
        current_user.add_product_to_cart(product, add_params[:quantity])
        @status = :ok
      end

      # DELETE /api/v1/cart/revoke/:item_id
      #
      # Removes a specified quantity of a product from the authenticated user's shopping cart,
      # or removes the entire item if quantity is not specified or is greater than/equal to
      # the current item quantity.
      #
      # @param [Integer] :item_id The ID of the cart item to modify or remove.
      # @param [Integer] :quantity_to_remove (Optional) The quantity to reduce. If not
      #                                     provided or if it's greater than/equal to
      #                                     current quantity, the item is fully removed.
      # @return [HTTP 204 No Content] On successful modification or removal.
      # @raise [ActiveRecord::RecordNotFound] If the cart item is not found in the user's cart (handled by User model).
      # @raise [ActiveRecord::RecordInvalid] If cart item validation fails during quantity reduction (handled by User model).
      def revoke
        current_user.remove_product_from_cart(revoke_params[:item_id], revoke_params[:quantity_to_remove])
        @status = :ok
      end

      # DELETE /api/v1/cart/clear
      #
      # Clears all items from the authenticated user's shopping cart.
      #
      # @return [HTTP 204 No Content] On successful clearing of the cart.
      # @raise [ActiveRecord::RecordInvalid] If clearing fails (e.g., due to database constraints - handled by User model).
      def clear
        current_user.clear_user_cart
        @status = :ok
      end

      private

      # Strong parameters for the 'add' action.
      #
      # @return [ActionController::Parameters] Permitted parameters for adding a product.
      def add_params
        params.permit(:product_id, :quantity)
      end

      # Strong parameters for the 'revoke' action.
      #
      # @return [ActionController::Parameters] Permitted parameters for revoking a product.
      def revoke_params
        params.permit(:item_id, :quantity_to_remove)
      end
    end
  end
end
