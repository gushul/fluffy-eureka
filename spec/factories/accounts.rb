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
FactoryBot.define do
  factory :account do
    association :user
    balance_cents { 10_000 }  # $100.00 default
  end
end
