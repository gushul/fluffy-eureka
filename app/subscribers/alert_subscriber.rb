module Subscribers
  class AlertSubscriber
    def self.call(payload)
      # PRD 7.579: AlertService trigger
      order_id = payload["source_id"] || payload["order_id"]

      AlertService.trigger(
        title: "Refund failed for order ##{order_id}", # lowercase 'failed' to match spec expectation if any
        payload: payload
      )
    end
  end
end
