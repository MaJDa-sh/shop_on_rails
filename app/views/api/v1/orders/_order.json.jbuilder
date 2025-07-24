# frozen_string_literal: true

json.cache! ['order_partial', order.id, order.updated_at, order.items.maximum(:updated_at) || Time.current] do
  json.id order.id
  json.user_id order.user_id # Or json.user { json.id order.user.id; json.mail order.user.mail } if user is eager-loaded
  json.total_amount order.total_amount
  json.status order.status
  json.payment_status order.payment_status # Assuming payment_status attribute
  json.created_at order.created_at
  json.updated_at order.updated_at

  json.items order.items do |item| # Assuming 'items' is the association for order_items
    json.id item.id
    json.product_name item.product_name # Or item.product.name if product is eager-loaded
    json.quantity item.quantity
    json.price_at_purchase item.price_at_purchase
    json.subtotal item.quantity * item.price_at_purchase
    # Add other item attributes if needed
  end
end
