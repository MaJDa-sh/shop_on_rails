# frozen_string_literal: true

module Services
  class AuthService
    SECRET_KEY = Rails.application.credentials.secret_key_base
    TOKEN_LIFETIME = 24.hours.to_i

    def self.redis
      @redis ||= Redis.current
    end

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

    def self.decode(token)
      return nil if blacklisted?(token)

      _decode_payload(token)
    end

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

    def self.blacklisted?(token)
      keys = redis.scan_each(match: "user:*:jwt:#{token}").to_a
      return false if keys.empty?

      redis.get(keys.first) == 'blacklisted'
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error: Failed to check JWT blacklist - #{e.message}")
      BlacklistedToken.exists?(token: token)
    end

    private

    def self._decode_payload(token)
      body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
      HashWithIndifferentAccess.new(body)
    rescue JWT::DecodeError, JWT::ExpiredSignature => e
      Rails.logger.warn("JWT Decode Error: #{e.message}")
      nil
    end
  end
end
