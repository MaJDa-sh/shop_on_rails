module DiagnosticsService
  def self.readiness_probe
    ActiveRecord::Base.connection
    { status: :ok, message: 'Application is ready' }
  rescue StandardError => e
    { status: :service_unavailable, errors: ["Readiness check failed: #{e.message}"] }
  end

  def self.health_probe
    checks = { database: false, redis: false, errors: [] }

    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      checks[:database] = true
    rescue StandardError => e
      checks[:errors] << "Database check failed: #{e.message}"
    end

    begin
      Redis.current.ping
      checks[:redis] = true
    rescue Redis::CannotConnectError => e
      checks[:errors] << "Redis check failed: #{e.message}"
    end

    if checks[:database] && checks[:redis]
      { status: :ok, message: 'Application is healthy', details: checks.except(:errors) }
    else
      { status: :service_unavailable, errors: checks[:errors], details: checks.except(:errors) }
    end
  end
end
