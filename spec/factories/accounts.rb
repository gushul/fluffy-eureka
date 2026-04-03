FactoryBot.define do
  factory :account do
    user
    balance { 100.0 }
  end
end
