require "rails_helper"

RSpec.describe Orders::CompleteService do
  subject(:result) { described_class.call(order: order) }

  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user, amount_cents: 5_000) }

  before do
    # Ensure account has balance
    user.account.update!(balance_cents: 10_000)
  end


  describe "successful completion" do
    it "returns success" do
      expect(result.success?).to be true
    end

    it "transitions order to success" do
      expect { result }.to change { order.reload.status }.from("created").to("success")
    end

    it "deducts balance from account" do
      expect { result }.to change { user.account.reload.balance_cents }
        .from(10_000).to(5_000)
    end

    it "creates a charge transaction" do
      expect { result }.to change(AccountTransaction, :count).by(1)
    end

    it "creates transaction with correct attributes" do
      result
      txn = AccountTransaction.last
      expect(txn.kind).to eq("charge")
      expect(txn.amount_cents).to eq(-5_000)
      expect(txn.order_id).to eq(order.id)
    end

    it "is atomic — order and balance change together" do
      allow_any_instance_of(Order).to receive(:complete!).and_raise(StandardError)
      expect { result rescue nil }.not_to change { user.account.reload.balance_cents }
    end
  end

  describe "insufficient funds" do
    before { user.account.update!(balance_cents: 1_000) }

    it "returns failure" do
      expect(result.success?).to be false
    end

    it "includes error message" do
      expect(result.errors.first).to match(/Insufficient funds/)
    end

    it "does not change order status" do
      expect { result }.not_to change { order.reload.status }
    end

    it "does not change balance" do
      expect { result }.not_to change { user.account.reload.balance_cents }
    end

    it "does not create transaction" do
      expect { result }.not_to change(AccountTransaction, :count)
    end
  end

  describe "invalid transition" do
    let(:order) { create(:order, :success, user: user) }

    it "returns failure" do
      expect(result.success?).to be false
    end

    it "includes error message" do
      expect(result.errors.first).to match(/Cannot complete order/)
    end
  end

  describe "already cancelled" do
    let(:order) { create(:order, :cancelled, user: user) }

    it "returns failure" do
      expect(result.success?).to be false
    end
  end
end
