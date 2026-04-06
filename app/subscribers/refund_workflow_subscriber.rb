  class RefundWorkflowSubscriber
    def self.call(payload)
      order_id = payload["source_id"]

      ProcessRefundJob.perform_later(order_id)
    end
  end
