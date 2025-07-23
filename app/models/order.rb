# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :destroy
  has_many :products, through: :items
  has_one :payment, dependent: :destroy

  enum status: { pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4, refunded: 5 }
  enum payment_status: { unpaid: 0, paid: 1, failed: 2, refunded: 3 }

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :payment_status, presence: true
  validates :order_date, presence: true

  before_validation :set_order_date, on: :create
  before_save :calculate_total_amount

  accepts_nested_attributes_for :items, allow_destroy: true

  scope :recent, -> { order(order_date: :desc).limit(10) }
  scope :completed, -> { where(status: :delivered) }
  scope :pending_payment, -> { where(payment_status: :unpaid) }

  def add_product(product, quantity)
    item = items.find_or_initialize_by(product: product)
    item.quantity = (item.quantity || 0) + quantity
    item.price_at_purchase = product.price
    item.save
    calculate_total_amount
    save
  end

  def total_items_count
    items.sum(:quantity)
  end

  def mark_as_paid!
    update!(payment_status: :paid)
  end

  def mark_as_shipped!
    update!(status: :shipped)
  end

  private

  def set_order_date
    self.order_date ||= Time.current
  end

  def calculate_total_amount
    self.total_amount = items.sum { |item| item.price_at_purchase * item.quantity }
  end
end
