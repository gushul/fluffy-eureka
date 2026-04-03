require "rails_helper"

RSpec.describe AccountTransaction, type: :model do
  describe "immutability" do
    let(:user)    { create(:user) }
    let(:order)   { create(:order, user: user) }

    let(:user2)    { create(:user) }
    let(:order2)   { create(:order, user: user2) }
    let(:another_account) { user2.account }

    let(:txn) do
      create(:account_transaction,
              account: user.account,
              order: order,
              amount_cents: -5000, kind: "charge")
    end

    it "raises error on update" do
      expect { txn.update!(kind: "reversal") }.to raise_error(ImmutableRecordError)
      expect { txn.update!(amount_cents: 1000) }.to raise_error(ImmutableRecordError)
      expect { txn.update!(order: order2, account: another_account) }.to raise_error(ImmutableRecordError)
    end

    it "raises error on destroy" do
      expect { txn.destroy! }.to raise_error(ImmutableRecordError)
    end
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:kind).in_array(%w[charge reversal]) }
  end
end
