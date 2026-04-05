module Subscribers
  class AlertSubscriber
    def self.call(payload)
      # Slack/PagerDuty alert
      AlertService.trigger(
        title:   "Refund failed for order ##{payload['order_id']}",
        payload: payload
      )
    end
  end
end
