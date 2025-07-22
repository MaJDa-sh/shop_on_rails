# frozen_string_literal: true

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
      # POST /api/v1/auth/register
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
      #   (e.g., { first_name: "Rober", last_name: "Moń" })
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

      # POST /api/v1/auth/login
      #
      # Initiates user authentication and generates a 2FA code if required.
      #
      # This endpoint verifies the user's email and password. If two-factor authentication
      # (2FA) is enabled, a new 2FA code is generated and sent to the user (e.g., via email).
      # If 2FA is not enabled, a JWT token is generated immediately.
      #
      # @param [String] :mail The user's email address
      # @param [String] :password The user's password
      def login
        @user = User.find_by(mail: params[:mail])
        if @user&.authenticate(params[:password])
          if @user.two_factor_enabled?
            @user.second_factor_code&.destroy
            @user.create_second_factor_code(code: SecureRandom.hex(8))
            UserMailer.send_2fa_code(@user, @user.second_factor_code.code).deliver_later
            @message = '2FA code sent to your email'
            @status = :accepted
          else
            @token = JsonWebToken.encode(user_id: @user.id)
            @status = :ok
          end
        else
          @errors = ['Invalid email or password']
          @status = :unauthorized
        end
      end

      # POST /api/v1/auth/verify_2fa
      #
      # Verifies a two-factor authentication (2FA) code and issues a JWT token.
      #
      # This endpoint verifies the provided 2FA code for a user. If valid, a JWT token
      # is generated, and the 2FA code is destroyed.
      #
      # @param [String] :mail The user's email address
      # @param [String] :second_factor_code The 2FA code sent to the user
      def verify_2fa
        @user = User.find_by(mail: params[:mail])
        if @user && @user.second_factor_code&.code == params[:second_factor_code]
          @token = JsonWebToken.encode(user_id: @user.id)
          @user.second_factor_code.destroy
          @status = :ok
        else
          @errors = ['Invalid 2FA code']
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
        if @user && @user.activation_code&.code == params[:activation_code]
          @user.update(active: true)
          @user.activation_code.destroy
          @message = 'Account activated'
          @status = :ok
        else
          @errors = ['Invalid activation code']
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
        if @user && @user.verification_code&.code == params[:verification_code]
          @user.update(verified: true)
          @user.verification_code.destroy
          @message = 'Account verified'
          @status = :ok
        else
          @errors = ['Invalid verification code']
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
        @user = User.find_by(mail: params[:mail])
        if @user
          # Invalidate any old codes and create a new one with an expiration time
          @user.reset_code&.destroy
          reset_code = @user.create_reset_code(
            code: SecureRandom.hex(16),
            expires_at: 2.hours.from_now
          )
          UserMailer.send_reset_code(@user, reset_code.code).deliver_later
        end
        # To prevent user enumeration, always return a generic success message.
        @message = 'If an account with that email exists, we have sent password reset instructions.'
        @status = :ok
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
        reset_code = ResetCode.find_by(code: params[:reset_code])

        # Check if the code exists and is not expired
        if reset_code && reset_code.expires_at > Time.current
          @user = reset_code.user
          if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
            reset_code.destroy # Invalidate the code after successful use
            @message = 'Password has been reset successfully.'
            @status = :ok
          else
            @errors = @user.errors.full_messages
            @status = :unprocessable_entity
          end
        else
          @errors = ['Invalid or expired reset code']
          @status = :unprocessable_entity
        end
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
