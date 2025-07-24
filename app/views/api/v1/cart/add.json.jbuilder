# frozen_string_literal: true

json.cache! ['cart_summary', current_user.id, @total_amount, @items_count,
             @cart_items.maximum(:updated_at) || Time.current] do
  if @errors.present?
    json.errors @errors
  else
    json.message @message if @message.present?
    json.cart_summary do
      json.total_amount @total_amount
      json.items_count @items_count
    end
  end
end
