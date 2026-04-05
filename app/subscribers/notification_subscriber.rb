module Subscribers
  class NotificationSubscriber
    def self.call(payload)
      order = Order.find(payload["order_id"])

      case payload["event_type"]
      when "order.completed"        then OrderMailer.completed(order).deliver_later
      when "order.refund_requested" then OrderMailer.refund_requested(order).deliver_later
      when "order.refunded"         then OrderMailer.refunded(order).deliver_later
      when "order.refund_failed"    then OrderMailer.refund_failed(order).deliver_later
      end
    end
  end
end
