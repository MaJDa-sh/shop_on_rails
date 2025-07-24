# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  # Namespace for API version v1.
  module V1
    # Handles diagnostic endpoints for monitoring application status.
    #
    # This controller provides readiness, health, and metrics endpoints, commonly
    # used by orchestration systems like Kubernetes to manage the application lifecycle.
    class DiagnosticsController < ApplicationController
      # GET /api/v1/diagnostics/readiness
      #
      # Checks if the application is ready to accept traffic.
      #
      # A readiness probe is used to determine if the application is fully initialized
      # and capable of processing new requests. If this check fails, the instance
      # should not receive new traffic until it becomes ready.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   a status response, typically with HTTP status 200 (OK) or 503 (Service Unavailable).
      # @see Services::DiagnosticsService.readiness_probe
      def readiness
        result = Services::DiagnosticsService.readiness_probe
        @status = result[:status]
        @message = result[:message]
        @errors = result[:errors]
      end

      # GET /api/v1/diagnostics/health
      #
      # Checks the ongoing health of the application and its dependencies.
      #
      # A health (or liveness) probe verifies that the application is running and that
      # critical dependencies (e.g., database, Redis) are responsive. If this check
      # fails, the application instance is considered unhealthy and should be restarted.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render a
      #   detailed health status, typically with HTTP status 200 (OK) or 503 (Service Unavailable).
      # @see Services::DiagnosticsService.health_probe
      def health
        result = Services::DiagnosticsService.health_probe
        @status = result[:status]
        @message = result[:message]
        @errors = result[:errors]
        @details = result[:details]
      end

      # GET /api/v1/diagnostics/metrics
      #
      # Exposes application metrics in Prometheus text format.
      #
      # This endpoint is designed to be scraped by a Prometheus server, providing
      # performance and business metrics for monitoring and alerting.
      #
      # @return [void] Renders metrics as plain text with a
      #   `text/plain; version=0.0.4` content type and a 200 OK status.
      # @see Services::PrometheusInstrumentor
      def metrics
        exporter = Prometheus::Client::Formats::Text.new
        render plain: exporter.export(Services::PrometheusInstrumentor.registry),
               content_type: 'text/plain; version=0.0.4'
      end
    end
  end
end
