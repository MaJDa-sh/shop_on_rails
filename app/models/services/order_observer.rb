class OrderObserver < ApplicationObserver
  observe :order

  def after_create(order)
    Rails.logger.info "OrderObserver: New order created (ID: #{order.id}, User: #{order.user.mail})"
  end

  def after_update(order)
    Rails.logger.info "OrderObserver: Order updated (ID: #{order.id}, Status: #{order.status})"
  end

  def after_destroy(order)
    Rails.logger.info "OrderObserver: Order deleted (ID: #{order.id})"
  end
end
