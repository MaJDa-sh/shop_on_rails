# frozen_string_literal: true

require 'jwt'

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  # Handles JWT (JSON Web Token) encoding, decoding, and blacklisting operations.
  #
  # This service provides a centralized way to manage authentication tokens,
  # including setting their lifetime, interacting with Redis for token status
  # (active/blacklisted), and handling JWT-related errors.
  class AuthService
    SECRET_KEY = Rails.application.credentials.secret_key_base
    TOKEN_LIFETIME = 24.hours.to_i

    # Returns the current Redis instance.
    #
    # @return [Redis] The Redis client instance.
    def self.redis
      @redis ||= Redis.current
    end

    # Encodes a given payload into a JWT token and stores its active status in Redis.
    #
    # The token includes an expiration time based on TOKEN_LIFETIME.
    # If Redis connection fails, a log error is recorded, but token generation proceeds.
    #
    # @param payload [Hash] The data to be encoded into the token. Must include :user_id.
    # @option payload [Integer] :user_id The ID of the user for whom the token is generated.
    # @return [String] The generated JWT token.
    def self.encode(payload)
      payload[:exp] = Time.now.to_i + TOKEN_LIFETIME
      token = JWT.encode(payload, SECRET_KEY, 'HS256')

      begin
        redis_key = "user:#{payload[:user_id]}:jwt:#{token}"
        redis.set(redis_key, 'active', ex: TOKEN_LIFETIME)
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error: Failed to cache JWT - #{e.message}")
      end

      token
    end

    # Decodes a JWT token.
    #
    # Returns nil if the token is blacklisted or cannot be decoded.
    #
    # @param token [String] The JWT token to decode.
    # @return [Hash, nil] The decoded token payload as a HashWithIndifferentAccess, or nil if invalid/blacklisted.
    def self.decode(token)
      return nil if blacklisted?(token)

      _decode_payload(token)
    end

    # Blacklists a given JWT token, preventing further use.
    #
    # The token's status is set to 'blacklisted' in Redis. If Redis connection
    # fails, a fallback mechanism (creating a BlacklistedToken record) is attempted.
    #
    # @param token [String] The JWT token to blacklist.
    # @return [Boolean] True if the token was successfully blacklisted (in Redis or DB), false otherwise.
    def self.blacklist!(token)
      decoded_payload = _decode_payload(token)
      return false unless decoded_payload && decoded_payload[:user_id]

      user_id = decoded_payload[:user_id]
      expires_at = Time.at(decoded_payload[:exp])
      redis_key = "user:#{user_id}:jwt:#{token}"

      begin
        redis.set(redis_key, 'blacklisted', ex: TOKEN_LIFETIME)
        true
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error: Failed to blacklist JWT - #{e.message}")
        BlacklistedToken.create(token: token, owner_id: user_id, expires_at: expires_at)
        false
      end
    end

    # Checks if a given JWT token is blacklisted.
    #
    # Primarily checks Redis for 'blacklisted' status. If Redis connection fails,
    # it falls back to checking the BlacklistedToken database table.
    #
    # @param token [String] The JWT token to check.
    # @return [Boolean] True if the token is blacklisted, false otherwise.
    def self.blacklisted?(token)
      keys = redis.scan_each(match: "user:*:jwt:#{token}").to_a
      return false if keys.empty?

      redis.get(keys.first) == 'blacklisted'
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: Failed to check JWT blacklist - #{e.message}")
      BlacklistedToken.exists?(token: token)
    end

    private

    # Decodes the JWT token payload.
    #
    # This is an internal helper method to handle the actual JWT decoding,
    # including algorithm verification and error handling for decoding issues
    # or expired signatures.
    #
    # @param token [String] The JWT token string.
    # @return [HashWithIndifferentAccess, nil] The decoded payload, or nil if decoding fails.
    def self._decode_payload(token)
      body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
      HashWithIndifferentAccess.new(body)
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn("JWT Decode Error: #{e.message}")
      nil
    end
  end
end
