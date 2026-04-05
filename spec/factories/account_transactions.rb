# == Schema Information
#
# Table name: account_transactions
#
#  id           :bigint           not null, primary key
#  amount_cents :bigint           not null
#  deleted_at   :datetime
#  description  :text
#  kind         :enum             not null
#  created_at   :datetime         not null
#  account_id   :bigint           not null
#  order_id     :bigint           not null
#
# Indexes
#
#  index_account_transactions_on_account_id  (account_id)
#  index_account_transactions_on_deleted_at  (deleted_at)
#  index_account_transactions_on_order_id    (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (order_id => orders.id)
#



FactoryBot.define do
  factory :account_transaction do
    association :account
    order { association :order, user: account.user }
    amount_cents { -5_000 }
    kind         { "charge" }

    trait :reversal do
      amount_cents { 5_000 }
      kind         { "reversal" }
    end
  end
end
