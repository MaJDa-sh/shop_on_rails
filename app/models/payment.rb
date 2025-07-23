# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order

  enum :status, { pending: 0, completed: 1, failed: 2, refunded: 3 }

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

  def self.handle_stripe_event(event)
    charge = event.data.object
    case event.type
    when 'charge.succeeded'
      process_charge_succeeded(charge)
    when 'charge.failed'
      process_charge_failed(charge)
    when 'charge.refunded'
      process_charge_refunded(charge)
    else
      Rails.logger.warn "Unhandled Stripe event type: #{event.type}"
    end
  end

  def self.process_charge_succeeded(charge)
    payment = find_by(stripe_charge_id: charge.id)
    return unless payment && !payment.completed?

    transaction do
      payment.mark_as_completed!
      payment.order.mark_as_paid!
    end
    Rails.logger.info "Webhook: Stripe charge succeeded for Payment ##{payment.id}"
  end

  def self.process_charge_failed(charge)
    payment = find_by(stripe_charge_id: charge.id)
    return unless payment && !payment.failed?

    failure_message = charge.failure_message || 'Charge failed for an unknown reason.'
    transaction do
      payment.mark_as_failed!(failure_message)
      payment.order.update!(payment_status: :failed)
    end
    Rails.logger.info "Webhook: Stripe charge failed for Payment ##{payment.id}"
  end

  def self.process_charge_refunded(charge)
    payment = find_by(stripe_charge_id: charge.id)
    return unless payment && !payment.refunded?

    transaction do
      payment.update!(status: :refunded)
      payment.order.update!(status: :refunded, payment_status: :refunded)
    end
    Rails.logger.info "Webhook: Stripe charge refunded for Payment ##{payment.id}"
  end

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
