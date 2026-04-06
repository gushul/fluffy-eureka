require "rails_helper"

RSpec.describe Orders::RequestRefundService do
  subject(:result) do
    described_class.new(order: order, actor: actor, reason: reason).call
  end

  let(:user)   { create(:user) }
  let(:order)  { create(:order, :success, user: user) }
  let(:actor)  { user }
  let(:reason) { "Item not received" }


  describe "successful refund request" do
    it { expect(result.success?).to be true }

    it "transitions to refund_requested" do
      expect { result }.to change { order.reload.status }
        .from("success").to("refund_requested")
    end

    it "stores the refund reason" do
      result
      expect(order.reload.refund_reason).to eq(reason)
    end

    it "creates a domain event" do
      expect { result }.to change(DomainEvent, :count).by(1)
    end

    it "domain event has correct attributes" do
      result
      event = DomainEvent.last
      expect(event.event_type).to eq("order.refund_requested")
      expect(event.source).to     eq(order)
    end

    it "creates an audit log" do
      expect { result }.to change(AuditLog, :count).by(1)
    end

    it "audit log captures status change" do
      result
      log = AuditLog.last
      expect(log.user_id).to eq(user.id)
      expect(log.audit_changes["status"]).to eq([ "success", "refund_requested" ])
      expect(log.audit_changes["refund_reason"]).to eq([ nil, reason ])
    end

    it "creates an outbox event with audit_log_created type" do
      expect { result }.to change(OutboxEvent, :count).by(1)
      event = OutboxEvent.last
      expect(event.event_type).to eq("audit_log_created")
      expect(event.payload["action"]).to eq("order.refund_requested")
      expect(event.payload["user_id"]).to eq(user.id)
    end
  end

  describe "invalid transition" do
    context "from created" do
      let(:order) { create(:order, user: user) }

      it { expect(result.success?).to be false }
      it { expect(result.error).to match(/Cannot request refund/) }
    end

    context "from cancelled" do
      let(:order) { create(:order, :cancelled, user: user) }

      it { expect(result.success?).to be false }
    end

    context "from already refunded" do
      let(:order) { create(:order, :refunded, user: user) }

      it { expect(result.success?).to be false }
    end
  end
end
