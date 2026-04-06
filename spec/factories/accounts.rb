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
    balance_cents { 0 }

    after(:create) do |account|
      if account.balance_cents > 0
        diff = account.balance_cents
        # Manual update_column to 0, then we do it properly via ledger?
        # No, it's already created with the balance. We just need a transaction to MATCH it.

        system_order = create(:order, user: account.user, amount_cents: diff, status: "success", description: "Initial balance sync")
        account.account_transactions.create!(
          order:        system_order,
          amount_cents: diff,
          kind:         "reversal",
          description:  "Initial ledger sync"
        )
      end
    end
  end
end
