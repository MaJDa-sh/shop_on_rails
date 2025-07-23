# frozen_string_literal: true

require 'jwt'

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    # Handles authentication-related operations for users via the API.
    #
    # This controller provides endpoints for user registration, login, account
    # activation, and verification, supporting secure authentication with JWT
    # and two-factor authentication (2FA). Responses are handled by Jbuilder templates.
    class AuthController < ApplicationController
      # POST /api/v1/auth/login
      #
      # Initiates user authentication and generates a 2FA code if required.
      #
      # This endpoint verifies the user's email and password. If two-factor authentication
      # (2FA) is enabled, a new 2FA code is generated and sent to the user (e.g., via email).
      # If 2FA is not enabled, a JWT token is generated immediately using HS256.
      #
      # @param [String] :mail The user's email address
      # @param [String] :password The user's password
      def login
        result = User.authenticate_user(params[:mail], params[:password])
        @user = result[:user]
        @token = result[:token]
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      # POST /api/v1/auth/verify_2fa
      #
      # Verifies a two-factor authentication (2FA) code and issues a JWT token.
      #
      # This endpoint verifies the provided 2FA code for a user. If valid, a JWT token
      # is generated using HS256, and the 2FA code is destroyed to prevent reuse.
      #
      # @param [String] :mail The user's email address
      # @param [String] :second_factor_code The 2FA code sent to the user
      def verify_2fa
        @user = User.find_by(mail: params[:mail])
        if @user
          result = @user.verify_2fa_code(params[:second_factor_code])
          @token = result[:token]
          @errors = result[:errors]
          @status = result[:status]
        else
          @errors = ['User not found']
          @status = :unauthorized
        end
      end

      # PATCH /api/v1/auth/activate
      #
      # Activates a user account using an activation code.
      #
      # This endpoint verifies the provided activation code and activates the user's
      # account by setting the `active` attribute to true. The activation code is then destroyed.
      #
      # @param [String] :mail The user's email address
      # @param [String] :activation_code The activation code sent to the user
      def activate
        @user = User.find_by(mail: params[:mail])
        if @user
          result = @user.activate_with_code(params[:activation_code])
          @message = result[:message]
          @errors = result[:errors]
          @status = result[:status]
        else
          @errors = ['User not found']
          @status = :unprocessable_entity
        end
      end

      # PATCH /api/v1/auth/verify
      #
      # Verifies a user account using a verification code.
      #
      # This endpoint verifies the provided verification code and marks the user's
      # account as verified by setting the `verified` attribute to true. The verification
      # code is then destroyed.
      #
      # @param [String] :mail The user's email address
      # @param [String] :verification_code The verification code sent to the user
      def verify
        @user = User.find_by(mail: params[:mail])
        if @user
          result = @user.verify_with_code(params[:verification_code])
          @message = result[:message]
          @errors = result[:errors]
          @status = result[:status]
        else
          @errors = ['User not found']
          @status = :unprocessable_entity
        end
      end

      # POST /api/v1/auth/password/reset
      #
      # Sends a password reset code to the user's email address.
      #
      # This endpoint finds a user by their email. If the user exists, it generates a
      # secure, single-use, and time-limited reset code and sends it via email.
      # It always returns a successful response to prevent email enumeration attacks.
      #
      # @param [String] :mail The user's email address
      def request_reset
        result = User.request_password_reset(params[:mail])
        @message = result[:message]
        @status = result[:status]
      end

      # PATCH /api/v1/auth/password/reset
      #
      # Resets the user's password using a valid reset code.
      #
      # This endpoint verifies the provided reset code. If the code is valid and
      # not expired, it updates the user's password and destroys the code to
      # prevent reuse.
      #
      # @param [String] :reset_code The password reset code sent to the user
      # @param [String] :password The new password for the account
      # @param [String] :password_confirmation The confirmation of the new password
      def confirm_reset
        result = User.reset_password_with_code(params[:reset_code], params[:password], params[:password_confirmation])
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      private

      # Defines permitted parameters for creating or updating a user.
      #
      # @return [ActionController::Parameters] Permitted parameters for the user
      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[first_name last_name]
        )
      end
    end
  end
end
