module Api
  module V1
    class PaymentsController < ApplicationController
      before_action :set_payment, only: %i[show update destroy]

      def create; end
      def destroy; end
      def update; end
      def show; end
      def index; end

      private

      def payment_params; end

      # Sets the @payments instance variable for actions that require a payment ID.
      #
      # This method is called before the show, update, and destroy actions via before_action.
      #
      # @return [Payment] The payment instance
      # @raise [ActiveRecord::RecordNotFound] If the product with the given ID does not exist
      def set_payment
        @product = Product.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        @errors = ['Product not found']
        @status = :not_found
      end
    end
  end
end
