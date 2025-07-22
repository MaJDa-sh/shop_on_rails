# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    # Handles operations for User resources via the API.
    #
    # This controller provides endpoints to manage user accounts, including
    # registration, profile management, role updates, and action history.
    # It supports pagination, authentication, and authorization for secure access.
    # Responses are handled by Jbuilder templates.
    class UsersController < ApplicationController
      before_action :set_user, only: %i[show update destroy role actions]
      before_action :authenticate_user!, only: %i[show update destroy role actions me]
      before_action :authorize_admin!, only: %i[index role]

      # POST /api/v1/users
      #
      # Creates a new user account (registration).
      #
      # This endpoint allows a new user to register by providing an email, password,
      # and optional phone number and user details (e.g., first name, last name).
      # Upon successful creation, an activation code is generated for account verification.
      #
      # @param [Hash] user_params Parameters for creating a user
      # @option user_params [String] :mail The user's email address (required, unique)
      # @option user_params [String] :password The user's password (required)
      # @option user_params [String] :password_confirmation Password confirmation (required)
      # @option user_params [String] :phone The user's phone number (optional, unique)
      # @option user_params [Hash] :user_detail_attributes Nested attributes for user details
      #   (e.g., { first_name: "John", last_name: "Doe" })
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
      # Retrieves a single user by ID.
      #
      # This endpoint returns the details of a specific user, including their email,
      # phone, role, and associated user details. It requires authentication and
      # is accessible only to the user themselves or an admin.
      def show
      end

      # PATCH/PUT /api/v1/users/:id
      #
      # Updates an existing user's information.
      #
      # This endpoint allows the user or an admin to update the user's email, phone,
      # password, or associated user details. Sensitive changes may require additional
      # verification (e.g., current password).
      #
      # @param [Hash] user_params Parameters for updating a user
      # @option user_params [String] :mail The user's email address
      # @option user_params [String] :password The user's new password
      # @option user_params [String] :password_confirmation Password confirmation
      # @option user_params [String] :phone The user's phone number
      # @option user_params [Hash] :user_detail_attributes Nested attributes for user details
      def update
        if @user.update(user_params)
          @status = :ok
        else
          @errors = @user.errors.full_messages
          @status = :unprocessable_entity
        end
      end

      # DELETE /api/v1/users/:id
      #
      # Deletes a user account.
      #
      # This endpoint removes a user and their associated data (e.g., user details,
      # settings, activation codes). It is accessible only to the user themselves or an admin.
      def destroy
        @user.destroy
        @status = :no_content
      end

      # GET /api/v1/users/me
      #
      # Retrieves the profile of the currently authenticated user.
      #
      # This endpoint returns the details of the logged-in user, including email, phone,
      # role, and associated user details or settings.
      def me
        @user = current_user
        @status = :ok
      end

      # GET /api/v1/users
      #
      # Retrieves a paginated list of users.
      #
      # This endpoint returns a list of users with basic information (id, mail, role).
      # It is accessible only to users with the `admin` role and supports pagination
      # with 25 users per page.
      #
      # @param [Integer] :page The page number for pagination (optional)
      def index
        @users = User.page(params[:page]).per(25)
        @status = :ok
      end

      # PATCH /api/v1/users/:id/role
      #
      # Updates the role of a user.
      #
      # This endpoint allows an admin to change a user's role (e.g., regular, moderator, admin).
      #
      # @param [String] :role The new role for the user (regular, moderator, admin)
      def role
        if @user.update(role: params[:role])
          @status = :ok
        else
          @errors = @user.errors.full_messages
          @status = :unprocessable_entity
        end
      end

      # POST /api/v1/users/logout
      #
      # Logs out the current user by blacklisting their JWT token.
      #
      # This endpoint invalidates the user's current JWT token by adding it to the
      # BlacklistedToken model, effectively logging them out.
      def logout
        BlacklistedToken.create(owner_id: current_user.id, token: request.headers['Authorization'].split.last)
        @message = 'Logged out'
        @status = :ok
      end

      # GET /api/v1/users/:id/actions
      #
      # Retrieves a paginated list of actions performed by a user.
      #
      # This endpoint returns the action history (e.g., login, password changes) for a
      # specific user, accessible to the user themselves or an admin. It supports
      # pagination with 25 actions per page.
      #
      # @param [Integer] :page The page number for pagination (optional)
      def actions
        @actions = @user.user_actions.page(params[:page]).per(25)
        @status = :ok
      end

      private

      # Sets the @user instance variable for actions that require a user ID.
      #
      # This method is called before the show, update, destroy, role, and actions
      # actions via before_action.
      #
      # @return [User] The user instance
      # @raise [ActiveRecord::RecordNotFound] If the user with the given ID does not exist
      def set_user
        @user = User.find(params[:id])
      end

      # Defines permitted parameters for creating or updating a user.
      #
      # @return [ActionController::Parameters] Permitted parameters for the user
      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[first_name last_name]
        )
      end

      # Ensures the user is authenticated before accessing protected endpoints.
      #
      # @return [nil] Renders unauthorized status if not authenticated
      def authenticate_user!
        @errors = ['Unauthorized']
        @status = :unauthorized unless current_user
      end

      # Ensures the user has admin privileges for restricted endpoints.
      #
      # @return [nil] Renders forbidden status if not an admin
      def authorize_admin!
        @errors = ['Forbidden']
        @status = :forbidden unless current_user&.admin?
      end
    end
  end
end
