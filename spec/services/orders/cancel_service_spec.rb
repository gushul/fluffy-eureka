require "rails_helper"

RSpec.describe Orders::CancelService do
  subject(:result) { described_class.call(order: order) }

  let(:user) { create(:user) }


  describe "cancelling a created order" do
    before { clear_balance(user.account); top_up_balance(user.account, 10_000) }

    let(:order) { create(:order, user: user, amount_cents: 5_000) }

    it "returns success" do
      expect(result.success?).to be true
    end

    it "transitions to cancelled" do
      expect { result }.to change { order.reload.status }.from("created").to("cancelled")
    end

    it "does NOT touch the balance" do
      expect { result }.not_to change { user.account.reload.balance_cents }
    end

    it "does NOT create any transaction" do
      expect { result }.not_to change(AccountTransaction, :count)
    end

    it "creates an audit log with correct user_id" do
      expect { result }.to change(AuditLog, :count).by(1)
      expect(AuditLog.last.user_id).to eq(user.id)
    end

    it "creates an outbox event with audit_log_created type" do
      expect { result }.to change(OutboxEvent, :count).by(1)
      event = OutboxEvent.last
      expect(event.event_type).to eq("audit_log_created")
      expect(event.payload["action"]).to eq("order.cancelled")
    end
  end

  describe "cancelling a successful order (reversal)" do
    let(:order) { create(:order, :success, user: user, amount_cents: 5_000) }

    before do
      # 1. Start with 10k.
      clear_balance(user.account)
      top_up_balance(user.account, 10_000)

      # 2. Charge the order. Ledger becomes 10k - 5k = 5k.
      AccountTransaction.create!(
        account:      user.account,
        order:        order,
        amount_cents: -5_000,
        kind:         "charge"
      )

      # 3. Manually sync balance to 5k (ledger sum). bypass callbacks to stay exact.
      user.account.update_column(:balance_cents, 5_000)
    end

    it "returns success" do
      expect(result.success?).to be true
    end

    it "transitions to cancelled" do
      expect { result }.to change { order.reload.status }.from("success").to("cancelled")
    end

    it "returns funds to account" do
      expect { result }.to change { user.account.reload.balance_cents }
        .from(5_000).to(10_000)
    end

    it "creates a reversal transaction" do
      expect { result }.to change(AccountTransaction, :count).by(1)
    end

    it "reversal has correct attributes" do
      result
      reversal = AccountTransaction.last
      expect(reversal.kind).to eq("reversal")
      expect(reversal.amount_cents).to eq(5_000)  # positive — money back
    end

    it "original charge transaction remains unchanged (immutability)" do
      result
      charge = AccountTransaction.find_by(kind: "charge")
      expect(charge.amount_cents).to eq(-5_000)
    end
  end

  describe "cancelling an already cancelled order" do
    let(:order) { create(:order, :cancelled, user: user) }

    it "returns failure" do
      expect(result.success?).to be false
    end

    it "includes error message" do
      expect(result.errors.first).to match(/Cannot cancel order/)
    end
  end

  describe "atomicity on reversal" do
    let(:order) { create(:order, :success, user: user, amount_cents: 5_000) }

    before { clear_balance(user.account); top_up_balance(user.account, 5_000) }

    it "does not change balance if cancel! raises" do
      allow(order).to receive(:cancel!).and_raise(StandardError)
      expect { result rescue nil }.not_to change { user.account.reload.balance_cents }
    end
  end
end
