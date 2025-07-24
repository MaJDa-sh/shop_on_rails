# frozen_string_literal: true

require 'jwt'

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles user authentication-related operations.
    #
    # Provides endpoints for login, two-factor authentication (2FA), account
    # activation, and password reset. Responses are rendered using Jbuilder templates.
    class AuthController < ApplicationController
      # POST /api/v1/auth/login
      #
      # Authenticates a user based on email and password.
      #
      # Verifies credentials. If 2FA is enabled, it generates and sends a
      # verification code. Otherwise, it immediately returns a JWT.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :password The user's password.
      #
      # @return [void] Sets instance variables (`@user`, `@token` (if 2FA disabled),
      #   `@message` (if 2FA enabled), and `@status` (`:ok`, `:accepted`, or `:unauthorized`))
      #   for the Jbuilder view.
      # @see User.authenticate_user
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
      # Verifies a two-factor authentication (2FA) code.
      #
      # Checks the validity of the 2FA code. If valid, it generates a JWT
      # and destroys the code to prevent reuse.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :second_factor_code The 2FA code sent to the user.
      #
      # @return [void] Sets the `@token` (on success) or `@errors` (on failure)
      #   instance variables, along with `@status` (`:ok` or `:unauthorized`), for the Jbuilder view.
      # @see User#verify_2fa_code
      def verify_2fa
        @user = User.find_by(mail: params[:mail])
        if @user
          result = @user.verify_2fa_code(params[:second_factor_code])
          @token = result[:token]
          @errors = result[:errors]
          @status = result[:status]
        else
          @errors = ['user not found']
          @status = :unauthorized
        end
      end

      # PATCH /api/v1/auth/activate
      #
      # Activates a user account with an activation code.
      #
      # Verifies the code and, if valid, sets the user's `active` attribute to
      # `true`, then destroys the used code.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :activation_code The activation code sent to the user.
      #
      # @return [void] Sets the `@message`, `@errors`, and `@status` (`:ok`
      #   or `:unprocessable_entity`) instance variables for the Jbuilder view.
      # @see User#activate_with_code
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
      # Verifies a user account with a verification code.
      #
      # Verifies the code and, if valid, sets the user's `verified` attribute to
      # `true`, then destroys the used code.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :verification_code The verification code sent to the user.
      #
      # @return [void] Sets the `@message`, `@errors`, and `@status` (`:ok`
      #   or `:unprocessable_entity`) instance variables for the Jbuilder view.
      # @see User#verify_with_code
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
      # Initiates the password reset process.
      #
      # Based on the email address, it sends a password reset code to the user.
      # Always returns a success response to prevent email enumeration attacks.
      #
      # @param [String] :mail The user's email address.
      #
      # @return [void] Sets the `@message` and `@status` (`:ok`) instance variables
      #   for the Jbuilder view.
      # @see User.request_password_reset
      def request_reset
        result = User.request_password_reset(params[:mail])
        @message = result[:message]
        @status = result[:status]
      end

      # PATCH /api/v1/auth/password/reset
      #
      # Confirms a password reset using a code.
      #
      # Verifies the reset code and, if valid, sets the new password for the user,
      # then destroys the used code.
      #
      # @param [String] :reset_code The reset code sent to the user.
      # @param [String] :password The new password.
      # @param [String] :password_confirmation The new password confirmation.
      #
      # @return [void] Sets the `@message`, `@errors`, and `@status` (`:ok`
      #   or `:unprocessable_entity`) instance variables for the Jbuilder view.
      # @see User.reset_password_with_code
      def confirm_reset
        result = User.reset_password_with_code(params[:reset_code], params[:password], params[:password_confirmation])
        @message = result[:message]
        @errors = result[:errors]
        @status = result[:status]
      end

      private

      # Defines permitted parameters for creating a user.
      # This is a "strong parameters" method to protect against mass assignment.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[first_name last_name]
        )
      end
    end
  end
end
