# == Schema Information
#
# Table name: orders
#
#  id            :bigint           not null, primary key
#  amount_cents  :bigint           not null
#  deleted_at    :datetime
#  description   :text
#  lock_version  :integer          default(0), not null
#  refund_reason :string
#  refunded_at   :datetime
#  status        :string           default("created"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_orders_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Order, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:account_transactions) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }
  end

  describe "state machine" do
    describe "when from created" do
      let(:order) { create(:order) }

      it "can complete" do
        expect(order.may_complete?).to be true
      end

      it "can cancel" do
        expect(order.may_cancel?).to be true
      end

      it "cannot complete twice" do
        order.complete!
        expect { order.complete! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe "when from success" do
      let(:order) { create(:order, :success) }

      it "can cancel" do
        expect(order.may_cancel?).to be true
      end

      it "cannot complete again" do
        expect(order.may_complete?).to be false
      end
    end

    describe "when from cancelled" do
      let(:order) { create(:order, :cancelled) }

      it "cannot complete"  do
        expect { order.complete! }.to raise_error(AASM::InvalidTransition)
      end

      it "cannot cancel again" do
        expect { order.cancel! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe "#amount" do
    it "converts cents to float" do
      order = build(:order, amount_cents: 9999)
      expect(order.amount).to eq(99.99)
    end
  end

  describe "#amount=" do
    it "stores value as cents" do
      order = build(:order)
      order.amount = 49.99
      expect(order.amount_cents).to eq(4999)
    end
  end

  describe "soft delete" do
    let(:order) { create(:order) }

    it "soft_delete! sets deleted_at" do
      expect { order.soft_delete! }.to change { order.reload.deleted_at }.from(nil)
    end

    it "excludes from default scope" do
      order.soft_delete!
      expect(described_class.all).not_to include(order)
    end

    it "visible via only_deleted" do
      order.soft_delete!
      expect(described_class.only_deleted).to include(order)
    end

    it "restore! brings it back" do
      order.soft_delete!
      order.restore!
      expect(described_class.all).to include(order)
    end
  end
end
