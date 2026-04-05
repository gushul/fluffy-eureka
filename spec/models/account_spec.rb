# == Schema Information
#
# Table name: accounts
#
#  id            :bigint           not null, primary key
#  balance_cents :bigint           default(0), not null
#  deleted_at    :datetime
#  lock_version  :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_accounts_on_deleted_at  (deleted_at)
#  index_accounts_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Account, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }

    it { is_expected.to have_many(:account_transactions) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:balance_cents).is_greater_than_or_equal_to(0) }
  end

  describe "#balance" do
    it "converts cents to float" do
      account = build(:account, balance_cents: 12_350)
      expect(account.balance).to eq(123.50)
    end

    it "handles zero" do
      account = build(:account, balance_cents: 0)
      expect(account.balance).to eq(0.0)
    end
  end

  describe "#balance=" do
    it "stores value as cents" do
      account = build(:account)
      account.balance = 99.99
      expect(account.balance_cents).to eq(9999)
    end
  end

  describe "soft delete" do
    let(:account) { create(:user).account }

    it "soft_delete! sets deleted_at" do
      expect { account.soft_delete! }.to change { account.reload.deleted_at }.from(nil)
    end

    it "excludes from default scope" do
      account.soft_delete!
      expect(described_class.all).not_to include(account)
    end

    it "visible via only_deleted" do
      account.soft_delete!
      expect(described_class.only_deleted).to include(account)
    end
  end
end
