# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  # Base controller for the API.
  #
  # Provides shared functionality for all API controllers, including authentication,
  # authorization, global exception handling, and setting the default response format.
  class ApplicationController < ActionController::API
    before_action :set_default_response_format

    rescue_from ActiveRecord::RecordNotFound do |exception|
      render json: { errors: [exception.message] }, status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
    end

    rescue_from ArgumentError do |exception|
      render json: { errors: [exception.message] }, status: :bad_request
    end

    class Unauthorized < StandardError; end
    rescue_from Unauthorized do |exception|
      render json: { errors: [exception.message] }, status: :unauthorized
    end

    class Forbidden < StandardError; end
    rescue_from Forbidden do |exception|
      render json: { errors: [exception.message] }, status: :forbidden
    end

    rescue_from StandardError do |exception|
      Rails.logger.error "Unhandled exception: #{exception.message}\n#{exception.backtrace.join("\n")}"
      render json: { errors: ['An unexpected error occurred.'] }, status: :internal_server_error
    end

    # Initializes the CanCanCan Ability object for the current user.
    # This is used by `load_and_authorize_resource` for authorization.
    #
    # @return [Ability] The Ability object for the current user.
    def current_ability
      @current_ability ||= Ability.new(current_user)
    end

    # A `before_action` filter to restrict access to admin users only.
    #
    # @raise [Api::Forbidden] If the current user is not an admin.
    def authorize_admin!
      raise Api::Forbidden, 'Forbidden' unless current_user&.admin?
    end

    # Memoizes and returns the authenticated user for the current request.
    # Finds the user based on the user_id from the decoded JWT.
    #
    # @return [User, nil] The authenticated user instance or nil if not found.
    def current_user
      @current_user ||= User.find(decoded_jwt_token[:user_id]) if decoded_jwt_token
    end

    # The primary authentication filter for securing endpoints.
    #
    # It performs the following steps:
    # 1. Extracts the JWT from the `Authorization` header.
    # 2. Decodes the token using the AuthService.
    # 3. Finds the user associated with the token.
    # 4. Verifies that the user's account is active and verified.
    #
    # @raise [Api::Unauthorized] If the token is missing, invalid, expired, or the user is not found.
    # @raise [Api::Forbidden] If the user's account is not active or verified.
    # @return [void]
    def authenticate_user!
      token = request.headers['Authorization']&.split&.last
      raise Api::Unauthorized, 'Missing token' unless token

      @decoded_jwt_token = Services::AuthService.decode(token)
      raise Api::Unauthorized, 'Invalid or expired token' unless @decoded_jwt_token

      raise Api::Unauthorized, 'User not found' unless current_user

      return if current_user.active? && current_user.verified?

      raise Api::Forbidden,
            'User account is not active or verified'
    end

    protected

    attr_reader :decoded_jwt_token

    # A `before_action` filter to force the request format to JSON.
    # This ensures consistent API responses.
    #
    # @return [void]
    def set_default_response_format
      request.format = :json
    end
  end
end
