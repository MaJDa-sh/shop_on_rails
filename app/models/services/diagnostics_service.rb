# frozen_string_literal: true

module Services
  class DiagnosticsService
    def self.readiness_probe
      Instrumentor.check_performed(:readiness)

      ActiveRecord::Base.connection
      { status: :ok, message: 'Application is ready' }
    rescue StandardError => e
      { status: :service_unavailable, errors: ["Readiness check failed: #{e.message}"] }
    end

    def self.health_probe
      Instrumentor.check_performed(:health)

      checks = { database: false, redis: false, errors: [] }

      begin
        ActiveRecord::Base.connection.execute('SELECT 1')
        checks[:database] = true
        Instrumentor.report_component_status(:database, is_up: true)
      rescue StandardError => e
        checks[:errors] << "Database check failed: #{e.message}"
        Instrumentor.report_component_status(:database, is_up: false, error: true)
      end

      begin
        Redis.current.ping
        checks[:redis] = true
        Instrumentor.report_component_status(:redis, is_up: true)
      rescue Redis::CannotConnectError => e
        checks[:errors] << "Redis check failed: #{e.message}"
        Instrumentor.report_component_status(:redis, is_up: false, error: true)
      end

      if checks[:errors].empty?
        { status: :ok, message: 'Application is healthy', details: checks.except(:errors) }
      else
        { status: :service_unavailable, errors: checks[:errors], details: checks.except(:errors) }
      end
    end
  end
end
