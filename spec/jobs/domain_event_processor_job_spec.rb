require "rails_helper"

RSpec.describe DomainEventProcessorJob do
  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user) }

  def create_event(event_type, status: "pending")
    DomainEvent.create!(
      event_type:  event_type,
      source:      order,
      payload:     { order_id: order.id, user_id: user.id },
      status:      status
    )
  end

  describe "#perform" do
    context "with pending events" do
      let!(:event) { create_event("order.completed") }

      it "processes pending events" do
        expect { described_class.new.perform }
          .to change { event.reload.status }.from("pending").to("done")
      end

      it "sets processed_at" do
        described_class.new.perform
        expect(event.reload.processed_at).to be_present
      end

      it "calls correct subscribers" do
        expect(NotificationSubscriber).to receive(:call)
        expect(ReconciliationSubscriber).to receive(:call)
        described_class.new.perform
      end
    end

    context "with already processed events" do
      let!(:event) { create_event("order.completed", status: "done") }

      it "skips done events" do
        expect(NotificationSubscriber).not_to receive(:call)
        described_class.new.perform
      end
    end

    context "when subscriber raises" do
      let!(:event) { create_event("order.completed") }

      before do
        allow(NotificationSubscriber)
          .to receive(:call).and_raise(StandardError, "SMTP timeout")
      end

      it "marks event as failed" do
        described_class.new.perform
        expect(event.reload.status).to eq("failed")
      end

      it "stores the error message" do
        described_class.new.perform
        expect(event.reload.last_error).to eq("SMTP timeout")
      end

      it "increments attempts" do
        described_class.new.perform
        expect(event.reload.attempts).to eq(1)
      end
    end

    context "with mixed statuses" do
      let!(:pending) { create_event("order.completed", status: "pending") }
      let!(:done)    { create_event("order.refunded",  status: "done") }
      let!(:failed)  { create_event("order.refunded",  status: "failed") }

      it "processes only pending events" do
        allow(NotificationSubscriber).to receive(:call)
        allow(ReconciliationSubscriber).to receive(:call)

        described_class.new.perform

        expect(pending.reload.status).to eq("done")
        expect(done.reload.status).to    eq("done")     # unchanged
        expect(failed.reload.status).to  eq("failed")   # unchanged
      end
    end
  end
end
