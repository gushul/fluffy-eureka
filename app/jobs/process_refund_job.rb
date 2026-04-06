class ProcessRefundJob < ApplicationJob
  queue_as :refunds

  def perform(order_id)
    order = Order.find(order_id)

    return unless order.refund_requested?

    Orders::ProcessRefundService.call(order: order)
  end
end
