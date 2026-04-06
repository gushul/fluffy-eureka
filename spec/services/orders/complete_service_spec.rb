require "rails_helper"
 
RSpec.describe Orders::CompleteService do
  let(:user)    { create(:user) }
  let(:order)   { create(:order, user: user, amount_cents: 5_000) }
  let(:account) { user.account }
  let(:actor)   { user }
 
  before { account.update!(balance_cents: 10_000) }
 
  subject(:result) { described_class.new(order: order, actor: actor).call }
 
  # ── Happy path ────────────────────────────────────────────
 
  describe "successful completion" do
    it { expect(result.success?).to be true }
 
    it "transitions order to success" do
      expect { result }.to change { order.reload.status }
        .from("created").to("success")
    end
 
    it "deducts amount from account balance" do
      expect { result }.to change { account.reload.balance_cents }
        .from(10_000).to(5_000)
    end
 
    it "creates a charge transaction" do
      expect { result }.to change(AccountTransaction, :count).by(1)
    end
 
    it "charge transaction has correct attributes" do
      result
      txn = AccountTransaction.last
      expect(txn.kind).to         eq("charge")
      expect(txn.amount_cents).to eq(-5_000)
      expect(txn.order_id).to     eq(order.id)
      expect(txn.account_id).to   eq(account.id)
    end
 
    it "creates a domain event" do
      expect { result }.to change(DomainEvent, :count).by(1)
    end
 
    it "domain event has correct attributes" do
      result
      event = DomainEvent.last
      expect(event.event_type).to  eq("order.completed")
      expect(event.source).to      eq(order)
      expect(event.status).to      eq("pending")
    end
 
    it "creates an audit log" do
      expect { result }.to change(AuditLog, :count).by(1)
    end
 
    it "audit log captures before/after state" do
      result
      log = AuditLog.last
      expect(log.action).to                              eq("order.completed")
      expect(log.auditable).to                           eq(order)
      expect(log.actor).to                               eq(actor)
      expect(log.changes["status"]).to                   eq(["created", "success"])
      expect(log.changes["balance_cents"]).to            eq([10_000, 5_000])
    end
  end
 
  # ── Atomicity ─────────────────────────────────────────────
 
  describe "atomicity" do
    it "rolls back balance if order transition fails" do
      allow_any_instance_of(Order).to receive(:complete!).and_raise(StandardError)
 
      expect { result rescue nil }
        .not_to change { account.reload.balance_cents }
    end
 
    it "does not create transaction if balance update fails" do
      allow_any_instance_of(Account).to receive(:update!).and_raise(StandardError)
 
      expect { result rescue nil }
        .not_to change(AccountTransaction, :count)
    end
 
    it "does not create domain event if order transition fails" do
      allow_any_instance_of(Order).to receive(:complete!).and_raise(StandardError)
 
      expect { result rescue nil }
        .not_to change(DomainEvent, :count)
    end
 
    it "does not create audit log if transaction fails" do
      allow_any_instance_of(Order).to receive(:complete!).and_raise(StandardError)
 
      expect { result rescue nil }
        .not_to change(AuditLog, :count)
    end
  end
 
  # ── Insufficient funds ────────────────────────────────────
 
  describe "insufficient funds" do
    before { account.update!(balance_cents: 1_000) }
 
    it { expect(result.success?).to be false }
    it { expect(result.error).to match(/Insufficient funds/) }
 
    it "does not change order status" do
      expect { result }.not_to change { order.reload.status }
    end
 
    it "does not change balance" do
      expect { result }.not_to change { account.reload.balance_cents }
    end
 
    it "does not create any records" do
      expect { result }
        .to  not_change(AccountTransaction, :count)
        .and not_change(DomainEvent, :count)
        .and not_change(AuditLog, :count)
    end
  end
 
  # ── Invalid transition ────────────────────────────────────
 
  describe "invalid transition" do
    context "when order is already success" do
      let(:order) { create(:order, :success, user: user) }
 
      it { expect(result.success?).to be false }
      it { expect(result.error).to match(/Cannot complete/) }
    end
 
    context "when order is cancelled" do
      let(:order) { create(:order, :cancelled, user: user) }
 
      it { expect(result.success?).to be false }
    end
  end
 
  # ── Optimistic lock ───────────────────────────────────────
 
  describe "concurrent modification" do
    it "returns retriable error on StaleObjectError" do
      # Simulate another process updating the order first
      Order.find(order.id).update_columns(lock_version: order.lock_version + 1)
 
      expect(result.success?).to be false
      expect(result.error).to match(/concurrently/)
    end
  end
end
