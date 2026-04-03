require 'rails_helper'

RSpec.describe Orders::CompleteService do
  subject(:call) { described_class.new(order).call }

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, balance: 100.0) }
  let(:order) { create(:order, user: user, amount: 20.0, status: :created) }

  before do
    account # ensure account is created before order
  end


  context "when order is in created status and balance is sufficient" do
    it "changes order status to success" do
      expect { call }.to change { order.reload.status }.from("created").to("success")
    end

    it "creates a debit transaction" do
      expect { call }.to change(Transaction, :count).by(1)
      transaction = Transaction.last
      expect(transaction.account).to eq(account)
      expect(transaction.order).to eq(order)
      expect(transaction.amount).to eq(20.0)
      expect(transaction.kind).to eq("debit")
    end

    it "decreases account balance by order amount" do
      expect { call }.to change { account.reload.balance }.by(-20.0)
    end
  end

  context "when balance is insufficient" do
    let(:account) { create(:account, user: user, balance: 10.0) }

    it "raises ActiveRecord::RecordInvalid" do
      expect { call }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "does not change order status" do
      expect { call rescue nil }.not_to change { order.reload.status }
    end

    it "does not create a transaction" do
      expect { call rescue nil }.not_to change(Transaction, :count)
    end
  end

  context "when order is already success" do
    let(:order) { create(:order, user: user, amount: 20.0, status: :success) }

    it "raises InvalidTransitionError" do
      expect { call }.to raise_error(InvalidTransitionError)
    end
  end
end
