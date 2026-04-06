# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  email      :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_deleted_at  (deleted_at)
#  index_users_on_email       (email) UNIQUE
#
require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_one(:account).dependent(:destroy) }
    it { is_expected.to have_many(:orders).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe "account auto-creation" do
    it "creates an account with zero balance after user is created" do
      user = create(:user)
      expect(user.account).to be_present
      expect(user.account.balance_cents).to eq(0)
    end
  end

  describe "soft delete" do
    let(:user) { create(:user) }

    it "soft_delete! sets deleted_at" do
      expect { user.soft_delete! }.to change { user.reload.deleted_at }.from(nil)
    end

    it "excludes soft-deleted records from default scope" do
      user.soft_delete!
      expect(described_class.all).not_to include(user)
    end

    it "exposes soft-deleted records via only_deleted" do
      user.soft_delete!
      expect(described_class.only_deleted).to include(user)
    end

    it "exposes all records via with_deleted" do
      user.soft_delete!
      expect(described_class.with_deleted).to include(user)
    end

    it "restore! makes record visible again" do
      user.soft_delete!
      user.restore!
      expect(described_class.all).to include(user)
    end

    it "soft_deleted? is true after soft delete" do
      user.soft_delete!
      expect(user.soft_deleted?).to be true
    end

    it "soft_deleted? is false for active record" do
      expect(user.soft_deleted?).to be false
    end
  end
end
