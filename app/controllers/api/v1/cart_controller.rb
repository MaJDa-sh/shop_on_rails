# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    class CartController < ApplicationController
      def add; end
      def revoke; end
      def clear; end

      def me; end
    end
  end
end
