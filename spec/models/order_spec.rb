require "rails_helper"

RSpec.describe Order, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_one(:account_transaction) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }
  end

  describe "state machine" do
    let(:order) { create(:order) }

    context "from created" do
      it "can transition to success" do
        expect(order.may_complete?).to be true
      end

      it "can transition to cancelled" do
        expect(order.may_cancel?).to be true
      end

      it "cannot transition to created again" do
        expect { order.complete!; order.complete! }.to raise_error(AASM::InvalidTransition)
      end
    end

    context "from success" do
      let(:order) { create(:order, :success) }

      it "can transition to cancelled" do
        expect(order.may_cancel?).to be true
      end

      it "cannot transition back to created" do
        expect(order.may_complete?).to be false
      end
    end

    context "from cancelled" do
      let(:order) { create(:order, :cancelled) }

      it "cannot transition to any other state" do
        expect(order.may_complete?).to be false
        expect(order.may_cancel?).to be false
      end
    end
  end

  describe "#amount" do
    it "converts cents to decimal correctly" do
      order = build(:order, amount_cents: 9999)
      expect(order.amount).to eq(99.99)
    end
  end
end
