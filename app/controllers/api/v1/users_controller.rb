# frozen_string_literal: true

require 'jwt'

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

      # POST /api/v1/users/create
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
      # is accessible only to the user themselves or an admin. The user must be active
      # and verified to access their profile.
      def show
        unless @user.accessible_by?(current_user)
          @errors = ['You can only view your own profile']
          @status = :forbidden
          return
        end
        return if @user.active? && @user.verified?

        @errors = ['User account is not active or verified']
        @status = :forbidden
      end

      # PATCH/PUT /api/v1/users/:id/update
      #
      # Updates an existing user's information.
      #
      # This endpoint allows the user or an admin to update the user's email, phone,
      # password, or associated user details. Sensitive changes may require additional
      # verification (e.g., current password). It requires authentication and is accessible
      # only to the user themselves or an admin.
      #
      # @param [Hash] user_params Parameters for updating a user
      # @option user_params [String] :mail The user's email address
      # @option user_params [String] :password The user's new password
      # @option user_params [String] :password_confirmation Password confirmation
      # @option user_params [String] :phone The user's phone number
      # @option user_params [Hash] :user_detail_attributes Nested attributes for user details
      def update
        unless @user.accessible_by?(current_user)
          @errors = ['You can only update your own profile']
          @status = :forbidden
          return
        end
        result = @user.update_with_params(user_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # PATCH/PUT /api/v1/users/:id/update_location
      #
      # Updates the user's location information.
      #
      # This endpoint allows the user or an admin to update or create a location record
      # associated with the user's details, including country, province, city, postal code,
      # street, building number, and apartment number. It requires authentication and is
      # accessible only to the user themselves or an admin. The user must be active and verified.
      #
      # @param [Hash] location_params Parameters for updating a location
      # @option location_params [String] :country The country (required)
      # @option location_params [String] :province The province or state (required)
      # @option location_params [String] :city The city (required)
      # @option location_params [String] :postal_code The postal code (required)
      # @option location_params [String] :street The street name (optional)
      # @option location_params [Integer] :building_number The building number (optional, must be positive)
      # @option location_params [Integer] :apartment_number The apartment number (optional, must be non-negative)
      def update_location
        unless @user.accessible_by?(current_user)
          @errors = ['You can only update your own location']
          @status = :forbidden
          return
        end
        unless @user.active? && @user.verified?
          @errors = ['User account is not active or verified']
          @status = :forbidden
          return
        end
        result = @user.update_user_location(location_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # PATCH/PUT /api/v1/users/:id/update_details
      #
      # Updates the user's personal details.
      #
      # This endpoint allows the user or an admin to update the user's personal details,
      # such as name, first name, and last name. It requires authentication and is accessible
      # only to the user themselves or an admin. The user must be active and verified.
      #
      # @param [Hash] user_detail_params Parameters for updating user details
      # @option user_detail_params [String] :name The full name (required)
      # @option user_detail_params [String] :first_name The first name (optional)
      # @option user_detail_params [String] :last_name The last name (optional)
      def update_details
        unless @user.accessible_by?(current_user)
          @errors = ['You can only update your own details']
          @status = :forbidden
          return
        end
        unless @user.active? && @user.verified?
          @errors = ['User account is not active or verified']
          @status = :forbidden
          return
        end
        result = @user.update_user_details(user_detail_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # PATCH/PUT /api/v1/users/:id/update_entrepreneur_details
      #
      # Updates the user's entrepreneur-specific details.
      #
      # This endpoint allows the user or an admin to update or create entrepreneur-related
      # data, such as business name, NIP, KRS, income, costs, and other business details.
      # It requires authentication and is accessible only to the user themselves or an admin.
      # The user must be active and verified.
      #
      # @param [Hash] entrepreneur_detail_params Parameters for updating entrepreneur details
      # @option entrepreneur_detail_params [String] :business_name The business name (optional)
      # @option entrepreneur_detail_params [String] :nip The NIP number (optional, unique)
      # @option entrepreneur_detail_params [String] :krs The KRS number (optional, unique)
      # @option entrepreneur_detail_params [String] :description The business description (optional)
      # @option entrepreneur_detail_params [String] :offer The business offer (optional)
      # @option entrepreneur_detail_params [Float] :income The business income (optional, non-negative)
      # @option entrepreneur_detail_params [Float] :costs The business costs (optional, non-negative)
      # @option entrepreneur_detail_params [Float] :funding_capital The funding capital (optional)
      # @option entrepreneur_detail_params [String] :industry The industry (optional)
      # @option entrepreneur_detail_params [Hash] :management_council_members JSONB data for council members (optional)
      # @option entrepreneur_detail_params [Hash] :decision_makers JSONB data for decision makers (optional)
      # @option entrepreneur_detail_params [String] :business_phone_number The business phone number (optional)
      # @option entrepreneur_detail_params [String] :business_mail The business email (optional)
      # @option entrepreneur_detail_params [String] :website_address The business website (optional)
      def update_entrepreneur_details
        unless @user.accessible_by?(current_user)
          @errors = ['You can only update your own entrepreneur details']
          @status = :forbidden
          return
        end
        unless @user.active? && @user.verified?
          @errors = ['User account is not active or verified']
          @status = :forbidden
          return
        end
        result = @user.update_user_entrepreneur_details(entrepreneur_detail_params)
        @errors = result[:errors]
        @status = result[:status]
      end

      # DELETE /api/v1/users/:id/delete
      #
      # Deletes a user account.
      #
      # This endpoint removes a user and their associated data (e.g., user details,
      # settings, activation codes). It is accessible only to the user themselves or an admin.
      def destroy
        unless @user.accessible_by?(current_user)
          @errors = ['You can only delete your own account']
          @status = :forbidden
          return
        end
        result = @user.destroy_user
        @status = result[:status]
      end

      # GET /api/v1/users/me
      #
      # Retrieves the profile of the currently authenticated user.
      #
      # This endpoint returns the details of the logged-in user, including email, phone,
      # role, and associated user details or settings. The user must be active and verified.
      def me
        @user = current_user
        if @user.active? && @user.verified?
          @status = :ok
        else
          @errors = ['User account is not active or verified']
          @status = :forbidden
        end
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
      # It requires admin privileges.
      #
      # @param [String] :role The new role for the user (regular, moderator, admin)
      def role
        result = @user.update_with_params(role: params[:role])
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/users/logout
      #
      # Logs out the current user by blacklisting their JWT token.
      #
      # This endpoint invalidates the user's current JWT token by adding it to the
      # BlacklistedToken model, effectively logging them out.
      def logout
        token = request.headers['Authorization']&.split&.last
        if token && current_user
          result = current_user.blacklist_token(token)
          @message = result[:message]
          @errors = result[:errors]
          @status = result[:status]
        else
          @errors = ['Invalid or missing token']
          @status = :unprocessable_entity
        end
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
        unless @user.accessible_by?(current_user)
          @errors = ['You can only view your own actions']
          @status = :forbidden
          return
        end
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
      rescue ActiveRecord::RecordNotFound
        @errors = ['User not found']
        @status = :not_found
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
      # Verifies the JWT token in the Authorization header, checks if it's blacklisted,
      # and sets the current_user. Renders unauthorized status if not authenticated.
      #
      # @return [nil] Renders unauthorized status if not authenticated
      def authenticate_user!
        token = request.headers['Authorization']&.split&.last
        if token
          begin
            decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true,
                                       { algorithm: 'HS256' })
            user_id = decoded_token[0]['user_id']

            if BlacklistedToken.exists?(token: token)
              @errors = ['Token is blacklisted']
              @status = :unauthorized
              return
            end

            @current_user = User.find_by(id: user_id)
            if @current_user
              unless @current_user.active? && @current_user.verified?
                @errors = ['User account is not active or verified']
                @status = :forbidden
              end
            else
              @errors = ['User not found']
              @status = :unauthorized
            end
          rescue JWT::DecodeError => e
            @errors = ["Invalid token: #{e.message}"]
            @status = :unauthorized
          end
        else
          @errors = ['Missing token']
          @status = :unauthorized
        end
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
