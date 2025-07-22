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
        @products = Product.includes(:product_photos).page(params[:page]).per(25)
        @status = :ok
      end

      # GET /api/v1/products/:id
      #
      # Retrieves a single product by ID.
      #
      # This endpoint returns the details of a specific product, including its name, price,
      # description, and associated photos.
      def show
        # @product is set by set_product
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

      # PATCH/PUT /api/v1/products/:id
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
        @errors = ['Product not found']
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
