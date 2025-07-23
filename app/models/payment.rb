# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order

  enum status: { pending: 0, completed: 1, failed: 2, refunded: 3 }

  attribute :stripe_token, :string
  attribute :error_message, :string

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :transaction_id, presence: true, uniqueness: true, allow_nil: true
  validates :payment_method, presence: true
  validates :stripe_charge_id, presence: true, if: :completed?
  validates :currency, presence: true, if: :completed?

  before_validation :set_default_currency, on: :create

  before_create :create_stripe_charge

  def mark_as_completed!
    update!(status: :completed)
  end

  def mark_as_failed!(message = nil)
    update!(status: :failed, error_message: message)
  end

  private

  def set_default_currency
    self.currency ||= 'PLN'
  end

  def create_stripe_charge
    return unless stripe_token.present? && amount.present? && order.user.present?

    begin
      charge = Stripe::Charge.create(
        amount: (amount * 100).to_i,
        currency: currency,
        source: stripe_token,
        description: "Order #{order.id} for user #{order.user.mail}",
        metadata: {
          order_id: order.id,
          user_id: order.user.id
        }
      )

      self.stripe_charge_id = charge.id
      self.transaction_id = charge.id
      self.status = :completed
      self.error_message = nil
    rescue Stripe::CardError => e
      body = e.json_body
      err = body[:error]
      Rails.logger.error "Stripe Card Error: status is #{e.http_status}, type is #{err[:type]}, code is #{err[:code]}, param is #{err[:param]}, message is #{err[:message]}."
      self.status = :failed
      self.error_message = err[:message]
      false
    rescue Stripe::RateLimitError, Stripe::InvalidRequestError, Stripe::AuthenticationError,
           Stripe::APIConnectionError, Stripe::StripeError => e
      Rails.logger.error "Stripe Error: #{e.message}"
      self.status = :failed
      self.error_message = e.message
      false
    rescue StandardError => e
      Rails.logger.error "Unexpected error during Stripe charge: #{e.message}"
      self.status = :failed
      self.error_message = "An unexpected error occurred: #{e.message}"
      false
    end
  end
end
