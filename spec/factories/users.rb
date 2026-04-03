FactoryBot.define do
  factory :user do
    name  { Faker::Name.first_name }
    email { Faker::Internet.unique.email }
  end
end
