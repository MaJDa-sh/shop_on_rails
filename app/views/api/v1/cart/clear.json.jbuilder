# frozen_string_literal: true

json.cache! ['cart_clear_summary', current_user.id, @total_amount, @items_count, @message] do
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
