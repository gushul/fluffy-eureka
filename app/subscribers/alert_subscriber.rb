  class AlertSubscriber
    def self.call(payload)
      order_id = payload["source_id"] || payload["order_id"]

      AlertService.trigger(
        title: "Refund failed for order ##{order_id}", # lowercase 'failed' to match spec expectation if any
        payload: payload
      )
    end
  end
