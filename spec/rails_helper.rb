require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'

require 'factory_bot_rails'
require 'testcontainers/postgres'
require 'testcontainers/redis'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!

  postgresql_container = Testcontainers::PostgresContainer.new('postgres:15-alpine')
                                                          .with_env('POSTGRES_DB', 'test')
                                                          .with_env('POSTGRES_PASSWORD', 'postgres')
                                                          .with_env('POSTGRES_USER', 'postgres')
                                                          .with_database('shop_on_rails_test')
  redis_container = Testcontainers::RedisContainer.new('redis:6.0-alpine')

  config.before(:suite) do
    postgresql_container.start
    redis_container.start

    ActiveRecord::Base.establish_connection(
      adapter: 'postgresql',
      host: postgresql_container.host,
      port: postgresql_container.port,
      database: postgresql_container.database,
      username: postgresql_container.username,
      password: postgresql_container.password
    )

    Redis.current = Redis.new(host: redis_container.host, port: redis_container.port)
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Tasks::DatabaseTasks.migrate
  end

  config.after(:suite) do
    postgresql_container.stop
    redis_container.stop
  end

  config.before(:each) do
    Redis.current.flushdb
  rescue StandardError
    nil
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
