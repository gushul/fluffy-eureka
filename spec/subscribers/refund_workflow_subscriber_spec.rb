require "rails_helper"

RSpec.describe RefundWorkflowSubscriber do
  let(:order)   { create(:order, :refund_requested) }
  let(:payload) { { "source_type" => "Order", "source_id" => order.id, "event_type" => "order.refund_requested" } }

  describe ".call" do
    it "enqueues a ProcessRefundJob with the correct order_id" do
      ActiveJob::Base.queue_adapter = :test

      expect {
        described_class.call(payload)
      }.to have_enqueued_job(ProcessRefundJob).with(order.id).on_queue("refunds")
    end
  end
end
