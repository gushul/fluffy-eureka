module Subscribers
  class ReconciliationSubscriber
    def self.call(payload)
      ReconciliationLog.create!(
        order_id:   payload["order_id"],
        event_type: payload["event_type"],
        amount:     payload["amount"],
        logged_at:  Time.current
      )
    end
  end
end
