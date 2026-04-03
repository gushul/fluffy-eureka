FactoryBot.define do
  factory :account do
    association :user
    balance_cents { 10_000 }  # $100.00 default
  end
end
