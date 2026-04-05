# == Schema Information
#
# Table name: orders
#
#  id            :bigint           not null, primary key
#  amount_cents  :bigint           not null
#  deleted_at    :datetime
#  description   :text
#  lock_version  :integer          default(0), not null
#  refund_reason :string
#  refunded_at   :datetime
#  status        :string           default("created"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_orders_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
