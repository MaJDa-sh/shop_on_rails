# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles CRUD operations and interactions for Product resources.
    #
    # Provides endpoints to list, show, create, update, and delete products,
    # as well as actions for liking, rating, and commenting.
    class ProductsController < ApplicationController
      before_action :authenticate_user!, except: %i[index show]
      load_and_authorize_resource

      # GET /api/v1/products
      #
      # Retrieves a paginated list of products.
      #
      # Supports pagination and includes associated photos, likes, and comments
      # to reduce N+1 queries.
      #
      # @param [Integer] :page (Optional) The page number for pagination.
      # @return [void] Sets `@products` for the Jbuilder view, rendering with
      #   a status of `:ok` (200).
      def index
        @products = Product.includes(:product_photos, :likes, :comments).page(params[:page]).per(25)
        @status = :ok
      end

      # GET /api/v1/products/:id
      #
      # Retrieves a single product by its ID.
      #
      # The `@product` instance variable is loaded and authorized automatically
      # by CanCanCan's `load_and_authorize_resource`.
      #
      # @return [void] Renders the `@product` using the Jbuilder view with a
      #   status of `:ok` (200).
      def show
        @status = :ok
      end

      # POST /api/v1/products
      #
      # Creates a new product (Admin/Moderator only).
      #
      # @param [Hash] :product The parameters for the product.
      # @option product [String] :name The product's name.
      # @option product [Decimal] :price The product's price.
      # @option product [String] :description The product's description.
      #
      # @return [void] On success, sets `@product` and renders with `:created` (201).
      #   On failure, sets `@errors` and renders with `:unprocessable_entity` (422).
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
      # Updates an existing product (Admin/Moderator only).
      #
      # The `@product` is loaded automatically by `load_and_authorize_resource`.
      #
      # @param [Hash] :product The parameters for the product.
      # @option product [String] :name The product's name.
      # @option product [Decimal] :price The product's price.
      # @option product [String] :description The product's description.
      #
      # @return [void] On success, renders with `:ok` (200). On failure, sets
      #   `@errors` and renders with `:unprocessable_entity` (422).
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
      # Deletes a product permanently (Admin/Moderator only).
      #
      # The `@product` is loaded automatically by `load_and_authorize_resource`.
      #
      # @return [void] Renders with a status of `:no_content` (204) on success.
      def destroy
        @product.destroy
        @status = :no_content
      end

      # POST /api/v1/products/:id/like
      #
      # Allows an authenticated user to like a product.
      #
      # A user can only like a product once. Logic is handled by the User model.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   a success or failure message with an appropriate status.
      # @see User#like_product
      def like
        result = current_user.like_product(@product)
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/products/:id/rate
      #
      # Allows an authenticated user to rate a product.
      #
      # A user can only rate a product once; subsequent calls will update the rating.
      # Logic is handled by the User model.
      #
      # @param [Hash] :product_rating The parameters for the rating.
      # @option product_rating [Integer] :rating The rating value (1-5).
      # @option product_rating [String] :comment (Optional) A comment.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   a success or failure message with an appropriate status.
      # @see User#rate_product
      def rate
        result = current_user.rate_product(@product, rate_params[:rating], rate_params[:comment])
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/products/:id/comment
      #
      # Allows an authenticated user to add a comment to a product.
      #
      # Logic is handled by the User model.
      #
      # @param [Hash] :product_comment The parameters for the comment.
      # @option product_comment [String] :content The comment's content.
      # @option product_comment [String] :parent_id (Optional) The ID of the parent comment.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   a success or failure message with an appropriate status.
      # @see User#add_comment_to_product
      def comment
        result = current_user.add_comment_to_product(@product, comment_params[:content], comment_params[:parent_id])
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      private

      # Defines permitted parameters for the 'rate' action.
      # @return [ActionController::Parameters] Permitted parameters.
      def rate_params
        params.require(:product_rating).permit(:rating, :comment)
      end

      # Defines permitted parameters for the 'comment' action.
      # @return [ActionController::Parameters] Permitted parameters.
      def comment_params
        params.require(:product_comment).permit(:content, :parent_id)
      end

      # Defines permitted parameters for creating or updating a product.
      # @return [ActionController::Parameters] Permitted parameters.
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
