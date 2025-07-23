# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    # Handles operations for Product resources via the API.
    #
    # This controller provides endpoints to list, show, create, update, and delete
    # products, with support for pagination and associated product photos.
    # Responses are handled by Jbuilder templates.
    class ProductsController < ApplicationController
      before_action :set_product, only: %i[show update destroy]

      # GET /api/v1/products
      #
      # Retrieves a paginated list of products with their associated photos.
      #
      # This endpoint returns a list of products with basic information (id, name, price, description)
      # and their associated photos. It supports pagination with 25 products per page.
      #
      # @param [Integer] :page The page number for pagination (optional)
      def index
        @products = Product.includes(:product_photos, :product_likes, :product_comments).page(params[:page]).per(25)
        @status = :ok
      end

      # GET /api/v1/products/:id
      #
      # Retrieves a single product by ID.
      #
      # This endpoint returns the details of a specific product, including its name, price,
      # description, and associated photos.
      def show
        @status = :ok
      end

      # POST /api/v1/products
      #
      # Creates a new product with the provided attributes.
      #
      # This endpoint allows the creation of a new product by providing a name, price,
      # description, and optional associated photos.
      #
      # @param [Hash] product_params Parameters for creating a product
      # @option product_params [String] :name The product's name (required)
      # @option product_params [Float] :price The product's price (required)
      # @option product_params [String] :description The product's description (optional)
      # @option product_params [Array<Hash>] :product_photos_attributes Nested attributes for product photos
      # @option product_params [Array<Integer>] :product_photo_ids IDs of associated product photos
      def create
        @product = Product.new(product_params)
        if @product.save
          @status = :created
        else
          @errors = @product.errors.full_messages
          @status = :unprocessable_entity
        end
      end

      # PUT /api/v1/products/:id
      #
      # Updates an existing product with the provided attributes.
      #
      # This endpoint allows updating a product's name, price, description, or associated photos.
      #
      # @param [Hash] product_params Parameters for updating a product
      # @option product_params [String] :name The product's name
      # @option product_params [Float] :price The product's price
      # @option product_params [String] :description The product's description
      # @option product_params [Array<Hash>] :product_photos_attributes Nested attributes for product photos
      # @option product_params [Array<Integer>] :product_photo_ids IDs of associated product photos
      def update
        if @product.update(product_params)
          @status = :ok
        else
          @errors = @product.errors.full_messages
          @status = :unprocessable_entity
        end
      end

      # DELETE /api/v1/products/:id
      #
      # Deletes a product by ID.
      #
      # This endpoint removes a product and its associated data (e.g., photos).
      def destroy
        @product.destroy
        @status = :no_content
      end

      # POST /api/v1/products/:id/like
      #
      # Allows the authenticated user to like a specific product.
      #
      # This endpoint creates a record of the user liking the product.
      # A user can like a product only once.
      #
      # @param [Integer] :id The ID of the product to like.
      # @return [JSON] A JSON object indicating success or failure.
      # @raise [ActiveRecord::RecordNotFound] If the product is not found.
      # @raise [ActiveRecord::RecordInvalid] If the like operation fails (e.g., user already liked).
      def like
        result = current_user.like_product(@product)
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/products/:id/rate
      #
      # Allows the authenticated user to rate a specific product.
      #
      # This endpoint creates or updates a user's rating for a product.
      # A user can rate a product only once.
      #
      # @param [Integer] :id The ID of the product to rate.
      # @param [Integer] :rating The rating value (1-5).
      # @param [String] :comment (Optional) A comment accompanying the rating.
      # @return [JSON] A JSON object indicating success or failure.
      # @raise [ActiveRecord::RecordNotFound] If the product is not found.
      # @raise [ActiveRecord::RecordInvalid] If the rating operation fails (e.g., invalid rating value, user already rated).
      def rate
        result = current_user.rate_product(@product, rate_params[:rating], rate_params[:comment])
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/products/:id/comment
      #
      # Allows the authenticated user to add a comment to a specific product.
      #
      # This endpoint creates a new comment associated with the product and the user.
      # Comments can be top-level or replies to existing comments.
      #
      # @param [Integer] :id The ID of the product to comment on.
      # @param [String] :content The content of the comment (required).
      # @param [Integer] :parent_id (Optional) The ID of the parent comment, if this is a reply.
      # @return [JSON] A JSON object indicating success or failure.
      # @raise [ActiveRecord::RecordNotFound] If the product or parent comment is not found.
      # @raise [ActiveRecord::RecordInvalid] If the comment creation fails (e.g., empty content).
      def comment
        result = current_user.add_comment_to_product(@product, comment_params[:content], comment_params[:parent_id])
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      private

      # Sets the @product instance variable for actions that require a product ID.
      #
      # This method is called before the show, update, and destroy actions via before_action.
      #
      # @return [Product] The product instance
      # @raise [ActiveRecord::RecordNotFound] If the product with the given ID does not exist
      def set_product
        @product = Product.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        @errors = ['product not found']
        @status = :not_found
      end

      # Defines permitted parameters for creating or updating a product.
      #
      # @return [ActionController::Parameters] Permitted parameters for the product
      def product_params
        params.require(:product).permit(
          :name, :price, :description,
          product_photos_attributes: %i[id _destroy],
          product_photo_ids: []
        )
      end
    end
  end
end
