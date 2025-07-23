# frozen_string_literal: true

class Redis
  class << self
    attr_accessor :current
  end
end

Redis.current = Redis.new(
  host: Rails.application.credentials.redis[:host] || 'localhost',
  port: Rails.application.credentials.redis[:port] || 6379,
  password: Rails.application.credentials.redis[:password],
  ssl: Rails.application.credentials.redis[:ssl] || false
)
