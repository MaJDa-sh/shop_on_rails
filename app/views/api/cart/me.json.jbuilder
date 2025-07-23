json.cart do
  json.total_amount @total_amount
  json.items_count @items_count

  json.items @cart_items do |item|
    json.item_id item.id
    json.quantity item.quantity
    json.price_at_purchase item.price_at_purchase
    json.subtotal item.quantity * item.price_at_purchase

    json.product do
      json.id item.product.id
      json.name item.product.name
    end
  end
end
