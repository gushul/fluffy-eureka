FactoryBot.define do
  factory :order do
    association :user
    amount_cents { 5_000 }  # $50.00 default
    status       { "created" }

    trait :success do
      status { "success" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
