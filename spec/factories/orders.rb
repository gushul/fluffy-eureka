FactoryBot.define do
  factory :order do
    user
    amount { 10.0 }
    status { :created }
  end
end
