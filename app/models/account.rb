class Account < ApplicationRecord
  belongs_to :user
  has_many :account_transactions, dependent: :destroy

  # Rails uses lock_version column automatically for optimistic locking
  # Raises ActiveRecord::StaleObjectError on concurrent update conflict
  validates :balance_cents, numericality: { greater_than_or_equal_to: 0 }

  # Convenience helpers — work in decimal outside, store cents inside
  def balance
    balance_cents / 100.0
  end

  def balance=(amount)
    self.balance_cents = (amount * 100).to_i
  end
end
