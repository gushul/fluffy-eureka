# == Schema Information
#
# Table name: reconciliation_logs
#
#  id         :bigint           not null, primary key
#  amount     :decimal(, )
#  event_type :string
#  logged_at  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  order_id   :bigint
#
class ReconciliationLog < ApplicationRecord
  belongs_to :order
end
