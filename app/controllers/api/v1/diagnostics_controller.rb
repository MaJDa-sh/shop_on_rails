# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    # Handles diagnostic endpoints for monitoring application health and readiness.
    #
    # This controller provides endpoints for readiness and health probes, used by
    # monitoring systems (e.g., Kubernetes) to check the application's status.
    # Responses are handled by Jbuilder templates.
    class DiagnosticsController < ApplicationController
      # GET /api/v1/diagnostics/readiness_probe
      #
      # Checks if the application is ready to handle requests.
      #
      # This endpoint verifies that the application is operational and capable of
      # processing requests. It returns a success status if the application is ready,
      # or a failure status with error details if not.
      def readiness_probe
        result = Diagnostics.readiness_probe
        @status = result[:status]
        @message = result[:message]
        @errors = result[:errors]
      end

      # GET /api/v1/diagnostics/health_probe
      #
      # Checks the health of the application and its dependencies.
      #
      # This endpoint verifies the health of critical dependencies, such as the database.
      # It returns a success status if all checks pass, or a failure status with error
      # details and dependency status if any check fails.
      def health_probe
        result = Diagnostics.health_probe
        @status = result[:status]
        @message = result[:message]
        @errors = result[:errors]
        @details = result[:details]
      end
    end
  end
end
