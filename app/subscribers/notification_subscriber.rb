module Subscribers
  class NotificationSubscriber
    def self.call(payload)
      event_type = payload["event_type"]
      order      = Order.find(payload["source_id"])

      # PRD 8.551: OrderMailer enqueuing
      case event_type
      when "order.completed"
        OrderMailer.completed(order).deliver_later
      when "order.cancelled"
        OrderMailer.cancelled(order).deliver_later
      when "order.refund_requested"
        OrderMailer.refund_requested(order).deliver_later
      when "order.refunded"
        OrderMailer.refunded(order).deliver_later
      when "order.refund_failed"
        OrderMailer.refund_failed(order).deliver_later
      when "order.refund_retried"
        OrderMailer.refund_retried(order).deliver_later
      end
    end
  end
end
