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
class Account < ApplicationRecord
  include SoftDeletable

  belongs_to :user
  has_many :account_transactions

  validates :balance_cents, numericality: { greater_than_or_equal_to: 0 }

  def balance
    balance_cents / 100.0
  end

  def balance=(amount)
    self.balance_cents = (amount * 100).to_i
  end
end
