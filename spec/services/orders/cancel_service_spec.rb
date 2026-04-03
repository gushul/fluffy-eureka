require 'rails_helper'

RSpec.describe Orders::CancelService do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, balance: 100.0) }
  let(:order) { create(:order, user: user, amount: 20.0, status: :success) }

  before do
    account # ensure account is created before order
  end

  subject(:call) { described_class.new(order).call }

  context "when order is in success status" do
    it "changes order status to cancelled" do
      expect { call }.to change { order.reload.status }.from("success").to("cancelled")
    end

    it "creates a storno transaction" do
      expect { call }.to change { Transaction.count }.by(1)
      transaction = Transaction.last
      expect(transaction.account).to eq(account)
      expect(transaction.order).to eq(order)
      expect(transaction.amount).to eq(-20.0)
      expect(transaction.kind).to eq("storno")
    end

    it "increases account balance by order amount" do
      expect { call }.to change { account.reload.balance }.by(20.0)
    end
  end

  context "when order is in created status" do
    let(:order) { create(:order, user: user, amount: 20.0, status: :created) }

    it "raises InvalidTransitionError" do
      expect { call }.to raise_error(InvalidTransitionError)
    end
  end
end
