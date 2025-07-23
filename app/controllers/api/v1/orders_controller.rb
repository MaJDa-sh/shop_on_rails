# frozen_string_literal: true

# Namespace for API-related controllers and resources.
#
# This module encapsulates all API endpoints for the application, providing
# a structured way to handle API requests.
module Api
  module V1
    class OrdersController < ApplicationController
      before_action :set_order, only: %i[show update destroy]

      def create; end
      def cancel; end
      def update; end

      def show; end
      def destroy; end
      def index; end
      def set_product; end

      def me; end

      private

      def order_params; end

      def set_order
        @order = Order.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        @errors = ['User not found']
        @status = :not_found
      end
    end
  end
end
