  class ReconciliationSubscriber
    def self.call(payload)
      order_id   = payload["source_id"]
      event_type = payload["event_type"]
      order      = Order.find(order_id)

      ReconciliationLog.create!(
        order:      order,
        event_type: event_type,
        amount:     order.amount,
        logged_at:  Time.current
      )
    end
  end
