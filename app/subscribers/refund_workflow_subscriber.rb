module Subscribers
  class RefundWorkflowSubscriber
    def self.call(payload)
      # PRD 8.588: For order.refund_requested begin processing
      order_id = payload["source_id"]

      ProcessRefundJob.perform_later(order_id)
    end
  end
end
