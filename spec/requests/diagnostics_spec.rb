# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Diagnostics', type: :request do
  path '/api/v1/diagnostics/readiness' do
    get('Checks if the application is ready to accept traffic') do
      tags 'Diagnostics'
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'ok' },
                 message: { type: :string, example: 'Application is ready' }
               }

        run_test!
      end

      response(503, 'service unavailable') do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'error' },
                 errors: { type: :array, items: { type: :string } }
               }

        run_test!
      end
    end
  end

  path '/api/v1/diagnostics/health' do
    get('Checks the ongoing health of the application and its dependencies') do
      tags 'Diagnostics'
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'ok' },
                 message: { type: :string, example: 'All systems operational' },
                 details: {
                   type: :object,
                   properties: {
                     database: { type: :string, example: 'ok' },
                     redis: { type: :string, example: 'ok' }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api/v1/diagnostics/metrics' do
    get('Exposes application metrics in Prometheus text format') do
      tags 'Diagnostics'
      produces 'text/plain'

      response(200, 'successful') do
        examples 'text/plain' => <<~METRICS
          my_request_latency_seconds_bucket{le="0.1"} 0
          my_request_latency_seconds_bucket{le="0.5"} 0
        METRICS

        run_test!
      end
    end
  end
end
