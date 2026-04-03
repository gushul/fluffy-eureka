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
