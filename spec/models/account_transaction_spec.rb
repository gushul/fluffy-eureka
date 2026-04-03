require "rails_helper"

RSpec.describe AccountTransaction, type: :model do
  let(:user)    { create(:user) }
  let(:order)   { create(:order, user: user) }
  let(:account) { user.account }

  describe "associations" do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:order) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount_cents) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
  end

  describe "cross-user validation" do
    context "when account and order belong to the same user" do
      it "is valid" do
        txn = build(:account_transaction, account: account, order: order)
        expect(txn).to be_valid
      end
    end

    context "when account and order belong to different users" do
      let(:other_user)    { create(:user) }
      let(:other_order)   { create(:order, user: other_user) }

      it "is invalid" do
        txn = build(:account_transaction, account: account, order: other_order)
        expect(txn).not_to be_valid
      end

      it "adds error on account" do
        txn = build(:account_transaction, account: account, order: other_order)
        txn.valid?
        expect(txn.errors[:account]).to include(
          "must belong to the same user as the order"
        )
      end

      it "raises on create!" do
        expect {
          described_class.create!(
            account:      account,
            order:        other_order,
            amount_cents: -5_000,
            kind:         "charge"
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "immutability" do
    let!(:txn) do
      described_class.create!(
        account:      account,
        order:        order,
        amount_cents: -5_000,
        kind:         "charge"
      )
    end
    let(:order_2) { create(:order) }
    let(:account_2) { create(:account, user: order_2.user) }

    it "raises ImmutableRecordError on update of financial fields" do
      expect { txn.update!(kind: "reversal") }.to raise_error(ImmutableRecordError)
    end

    it "raises ImmutableRecordError on amount change" do
      expect { txn.update!(amount_cents: -1) }.to raise_error(ImmutableRecordError)
    end


    it "raises ImmutableRecordError on associations changes" do
      expect { txn.update!(order: order_2, account: account_2) }.to raise_error(ImmutableRecordError)
    end


    it "raises ImmutableRecordError on hard destroy" do
      expect { txn.destroy! }.to raise_error(ImmutableRecordError)
    end

    it "allows soft_delete! — only deleted_at changes" do
      expect { txn.soft_delete! }.not_to raise_error
      expect(txn.reload.deleted_at).not_to be_nil
    end

    it "allows restore! after soft delete" do
      txn.soft_delete!
      expect { txn.restore! }.not_to raise_error
      expect(described_class.with_deleted.find(txn.id).deleted_at).to be_nil
    end

    it "does not allow simultaneous field + deleted_at change" do
      txn.kind       = "reversal"
      txn.deleted_at = Time.current
      expect { txn.save! }.to raise_error(ImmutableRecordError)
    end
  end

  describe "soft delete" do
    let!(:txn) do
      described_class.create!(
        account:      account,
        order:        order,
        amount_cents: -5_000,
        kind:         "charge"
      )
    end

    it "soft_delete! sets deleted_at" do
      expect { txn.soft_delete! }.to change { txn.reload.deleted_at }.from(nil)
    end

    it "excludes from default scope" do
      txn.soft_delete!
      expect(described_class.all).not_to include(txn)
    end

    it "visible via only_deleted" do
      txn.soft_delete!
      expect(described_class.only_deleted).to include(txn)
    end
  end

  describe "#amount" do
    it "returns negative for charges" do
      txn = build(:account_transaction, amount_cents: -5_000, kind: "charge")
      expect(txn.amount).to eq(-50.0)
    end

    it "returns positive for reversals" do
      txn = build(:account_transaction, amount_cents: 5_000, kind: "reversal")
      expect(txn.amount).to eq(50.0)
    end
  end
end
