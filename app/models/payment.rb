# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order

  enum :status, { pending: 0, completed: 1, failed: 2, refunded: 3 }

  attribute :error_message, :string

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :transaction_id, uniqueness: true, allow_nil: true
  validates :payment_method, presence: true
  validates :stripe_charge_id, presence: true, if: :completed?
  validates :currency, presence: true, if: :completed?

  before_validation :set_default_currency, on: :create

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
end
