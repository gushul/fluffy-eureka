require "rails_helper"
 
RSpec.describe Orders::ProcessRefundService do
  let(:user)    { create(:user) }
  let(:order)   { create(:order, :refund_requested, user: user, amount_cents: 5_000) }
  let(:account) { user.account }
 
  before { account.update!(balance_cents: 5_000) }
 
  subject(:result) { described_class.new(order: order).call }
 
  describe "successful refund processing" do
    it { expect(result.success?).to be true }
 
    it "transitions to refunded" do
      expect { result }.to change { order.reload.status }
        .from("refund_requested").to("refunded")
    end
 
    it "returns funds to account" do
      expect { result }.to change { account.reload.balance_cents }
        .from(5_000).to(10_000)
    end
 
    it "creates a reversal transaction" do
      expect { result }.to change(AccountTransaction, :count).by(1)
    end
 
    it "reversal has correct attributes" do
      result
      txn = AccountTransaction.last
      expect(txn.kind).to         eq("reversal")
      expect(txn.amount_cents).to eq(5_000)   # positive — money back
    end
 
    it "sets refunded_at timestamp" do
      result
      expect(order.reload.refunded_at).to be_present
    end
 
    it "creates order.refunded domain event" do
      result
      event = DomainEvent.last
      expect(event.event_type).to eq("order.refunded")
    end
 
    it "creates an audit log with before/after balance" do
      result
      log = AuditLog.last
      expect(log.changes["balance_cents"]).to eq([5_000, 10_000])
      expect(log.changes["status"]).to        eq(["refund_requested", "refunded"])
    end
  end
 
  describe "failed refund" do
    before do
      allow_any_instance_of(Account).to receive(:update!)
        .and_raise(StandardError, "Gateway timeout")
    end
 
    it "transitions to refund_failed" do
      expect { result rescue nil }.to change { order.reload.status }
        .to("refund_failed")
    end
 
    it "creates order.refund_failed domain event" do
      result rescue nil
      event = DomainEvent.find_by(event_type: "order.refund_failed")
      expect(event).to be_present
    end
 
    it "does not change balance" do
      expect { result rescue nil }
        .not_to change { account.reload.balance_cents }
    end
  end
 
  describe "atomicity" do
    it "rolls back balance if complete_refund! fails" do
      allow_any_instance_of(Order).to receive(:complete_refund!).and_raise(StandardError)
 
      expect { result rescue nil }
        .not_to change { account.reload.balance_cents }
    end
  end
 
  describe "invalid transition" do
    context "from success (not yet requested)" do
      let(:order) { create(:order, :success, user: user) }
 
      it { expect(result.success?).to be false }
      it { expect(result.error).to match(/Cannot process refund/) }
    end
  end
end
