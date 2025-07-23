# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    class OrdersController < ApplicationController
      def create; end
      def cancel; end
      def update; end

      def show; end
      def destroy; end
      def index; end
      def set_product; end

      private

      def order_params; end
    end
  end
end
