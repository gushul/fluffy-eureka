

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
