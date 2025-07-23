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

  def update_with_params(params)
    if update(params)
      { status: :ok }
    else
      { errors: errors.full_messages, status: :unprocessable_entity }
    end
  end

  def destroy_order
    destroy
    { status: :no_content }
  end

  def cancel_order
    unless pending? || processing?
      return { errors: ["Nie można anulować zamówienia w obecnym stanie: #{status}"], status: :unprocessable_entity }
    end

    if update(status: :cancelled)
      { message: 'Zamówienie zostało pomyślnie anulowane', status: :ok }
    else
      { errors: errors.full_messages, status: :unprocessable_entity }
    end
  end

  def self.create_from_cart_for(user)
    cart_items_to_move = user.cart_items.includes(:product)
    raise ArgumentError, 'Twój koszyk jest pusty' if cart_items_to_move.empty?

    order = nil
    transaction do
      order = user.orders.create!(status: :pending, payment_status: :unpaid)
      cart_items_to_move.update_all(order_id: order.id)
      order.reload.save!
    end
    order
  end

  def self.for_user(user)
    if user.admin?
      includes(:user, :items).order(created_at: :desc)
    else
      user.orders.includes(:items).order(created_at: :desc)
    end
  end

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

  def accessible_by?(user)
    self.user == user || user.admin?
  end

  def manageable_by?(user)
    user.admin?
  end

  private

  def set_order_date
    self.order_date ||= Time.current
  end

  def calculate_total_amount
    self.total_amount = items.sum { |item| item.price_at_purchase * item.quantity }
  end
end
