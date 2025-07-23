# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
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

    # Ensures the user has admin privileges for restricted endpoints.
    #
    # @return [nil] Renders forbidden status if not an admin
    # @raise [Api::Forbidden] If the current user does not have admin privileges.
    def authorize_admin!
      raise Api::Forbidden, 'Forbidden' unless current_user&.admin?
    end

    # Helper method to retrieve the current authenticated user.
    #
    # This method should be implemented to fetch the user based on authentication
    # credentials (e.g., from a JWT token).
    #
    # @return [User, nil] The authenticated User object, or nil if not authenticated.
    def current_user
      @current_user ||= decoded_jwt_token && User.find_by(id: decoded_jwt_token['user_id'])
    end

    # Ensures the user is authenticated before accessing protected endpoints.
    #
    # Verifies the JWT token in the Authorization header, checks if it's blacklisted,
    # and sets the current_user. Raises an exception if not authenticated.
    #
    # @return [nil]
    # @raise [Api::Unauthorized] If authentication fails (missing/invalid token, blacklisted, user not found).
    # @raise [Api::Forbidden] If user account is not active or verified.
    def authenticate_user!
      token = request.headers['Authorization']&.split&.last
      raise Api::Unauthorized, 'Missing token' unless token

      begin
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true,
                                   { algorithm: 'HS256' })
        @decoded_jwt_token = decoded_token[0]

        raise Api::Unauthorized, 'Token is blacklisted' if BlacklistedToken.exists?(token: token)

        raise Api::Unauthorized, 'User not found' unless current_user

        unless current_user.active? && current_user.verified?
          raise Api::Forbidden, 'User account is not active or verified'
        end
      rescue JWT::DecodeError => e
        raise Api::Unauthorized, "Invalid token: #{e.message}"
      end
    end

    protected

    attr_reader :decoded_jwt_token

    def set_default_response_format
      request.format = :json
    end
  end
end
