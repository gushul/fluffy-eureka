FactoryBot.define do
  factory :transaction do
    account
    order
    amount { 10.0 }
    kind { :debit }
  end
end
