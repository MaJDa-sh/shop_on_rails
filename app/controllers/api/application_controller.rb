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

    def current_ability
      @current_ability ||= Ability.new(current_user)
    end

    def authorize_admin!
      raise Api::Forbidden, 'Forbidden' unless current_user&.admin?
    end

    def current_user
      @current_user ||= User.find_by(id: decoded_jwt_token[:user_id]) if decoded_jwt_token
    end

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

    def set_default_response_format
      request.format = :json
    end
  end
end
