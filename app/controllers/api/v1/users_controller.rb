# frozen_string_literal: true

require 'jwt'

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles operations for User resources via the API.
    #
    # Provides endpoints for user registration, profile management, role updates,
    # and action history. It supports authentication and authorization for secure access.
    class UsersController < ApplicationController
      load_and_authorize_resource except: %i[create me logout]
      before_action :authenticate_user!,
                    only: %i[show update destroy role actions me logout update_location update_details
                             update_entrepreneur_details]
      before_action :authorize_admin!, only: %i[index role]

      # POST /api/v1/users
      #
      # Creates a new user account (registration).
      #
      # Upon successful creation, an activation code is generated and associated
      # with the user's account for later verification.
      #
      # @param [Hash] :user The parameters for the user.
      # @option user [String] :mail User's email (required, unique).
      # @option user [String] :password User's password (required).
      #
      # @return [void] On success, sets `@user` and renders with `:created` (201).
      #   On failure, sets `@errors` and renders with `:unprocessable_entity` (422).
      def create
        @user = User.new(user_params)
        if @user.save
          @user.create_activation_code(code: SecureRandom.hex(16))
          @status = :created
        else
          @errors = @user.errors.full_messages
          @status = :unprocessable_entity
        end
      end

      # GET /api/v1/users/:id
      #
      # Retrieves a single user by their ID.
      #
      # Accessible only to the user themselves or an admin. The `@user` instance
      # variable is loaded and authorized automatically by CanCanCan.
      #
      # @return [void] Renders the `@user` using the Jbuilder view with a
      #   status of `:ok` (200).
      def show
        @status = :ok
      end

      # PATCH/PUT /api/v1/users/:id
      #
      # Updates an existing user's information.
      #
      # Accessible only to the user themselves or an admin. The `@user` instance
      # variable is loaded automatically by CanCanCan.
      #
      # @param [Hash] :user The parameters for updating the user.
      #
      # @return [void] Renders with `:ok` (200) on success. On failure, sets
      #   `@errors` and renders with `:unprocessable_entity` (422).
      # @see User#update_with_params
      def update
        result = @user.update_with_params(user_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # PATCH /api/v1/users/:id/update_location
      #
      # Updates the user's location information.
      #
      # @param [Hash] :location The parameters for the location.
      #
      # @return [void] Renders with `:ok` (200) on success or an error status
      #   on failure.
      # @see User#update_user_location
      def update_location
        result = @user.update_user_location(location_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # PATCH /api/v1/users/:id/update_details
      #
      # Updates the user's personal details.
      #
      # @param [Hash] :user_detail The parameters for the user's details.
      #
      # @return [void] Renders with `:ok` (200) on success or an error status
      #   on failure.
      # @see User#update_user_details
      def update_details
        result = @user.update_user_details(user_detail_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # PATCH /api/v1/users/:id/update_entrepreneur_details
      #
      # Updates the user's entrepreneur-specific details.
      #
      # @note The manual authorization checks in this action may be redundant if
      #   they are already handled by your CanCanCan ability file.
      #
      # @param [Hash] :entrepreneur_detail The parameters for the entrepreneur details.
      #
      # @return [void] Renders with `:ok` (200) on success or an error status
      #   on failure.
      # @see User#update_user_entrepreneur_details
      def update_entrepreneur_details
        unless @user.active? && @user.verified?
          @errors = ['User account is not active or verified.']
          @status = :forbidden
          return
        end

        result = @user.update_user_entrepreneur_details(entrepreneur_detail_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # DELETE /api/v1/users/:id
      #
      # Deletes a user account.
      #
      # Accessible only to the user themselves or an admin.
      #
      # @return [void] Renders with a status of `:no_content` (204) on success.
      # @see User#destroy_user
      def destroy
        result = @user.destroy_user
        @status = result[:status]
      end

      # GET /api/v1/users/me
      #
      # Retrieves the profile of the currently authenticated user.
      #
      # @return [void] Sets `@user` to `current_user` and renders with a
      #   status of `:ok` (200).
      def me
        @user = current_user
        @status = :ok
      end

      # GET /api/v1/users
      #
      # Retrieves a paginated list of all users (Admin only).
      #
      # @param [Integer] :page (Optional) The page number for pagination.
      #
      # @return [void] Sets `@users` for the Jbuilder view, rendering with
      #   a status of `:ok` (200).
      def index
        @users = User.page(params[:page]).per(25)
        @status = :ok
      end

      # PATCH /api/v1/users/:id/role/update
      #
      # Updates the role of a specific user (Admin only).
      #
      # @param [String] :role The new role for the user (e.g., "moderator", "admin").
      #
      # @return [void] Renders with `:ok` (200) on success or an error status
      #   on failure.
      def role
        result = @user.update_with_params(role: params[:role])
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/users/logout
      #
      # Logs out the current user by blacklisting their JWT.
      #
      # The token is extracted from the `Authorization` header.
      #
      # @return [void] Renders a success or failure message with an appropriate status.
      # @see User#blacklist_token
      def logout
        token = request.headers['Authorization']&.split&.last
        result = current_user.blacklist_token(token)
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # GET /api/v1/users/:id/actions
      #
      # Retrieves a paginated history of a user's actions.
      #
      # Accessible only to the user themselves or an admin.
      #
      # @param [Integer] :page (Optional) The page number for pagination.
      #
      # @return [void] Sets `@actions` for the Jbuilder view, rendering with
      #   a status of `:ok` (200).
      def actions
        @actions = @user.user_actions.page(params[:page]).per(25)
        @status = :ok
      end

      private

      # Defines permitted parameters for creating or updating a user.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[first_name last_name]
        )
      end

      # Defines permitted parameters for updating a user's location.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def location_params
        params.require(:location).permit(
          :country, :province, :city, :postal_code, :street,
          :building_number, :apartment_number
        )
      end

      # Defines permitted parameters for updating a user's personal details.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def user_detail_params
        params.require(:user_detail).permit(:name, :first_name, :last_name)
      end

      # Defines permitted parameters for updating a user's entrepreneur details.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def entrepreneur_detail_params
        params.require(:entrepreneur_detail).permit(
          :business_name, :nip, :krs, :description, :offer, :income, :costs,
          :funding_capital, :industry, :business_phone_number, :business_mail,
          :website_address,
          management_council_members: {},
          decision_makers: {}
        )
      end
    end
  end
end
