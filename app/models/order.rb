class Order < ApplicationRecord
  include AASM
  include SoftDeletable

  belongs_to :user
  has_one :account_transaction, dependent: :destroy

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :user,   presence: true

  aasm column: :status do
    state :created, initial: true
    state :success
    state :cancelled

    # created → success: triggers account balance substraction
    event :complete do
      transitions from: :created, to: :success
    end

    # created → cancelled: no financial impact
    # success → cancelled: triggers accout balance strono
    event :cancel do
      transitions from: %i[created success], to: :cancelled
    end
  end

  def amount
    amount_cents / 100.0
  end

  def amount=(value)
    self.amount_cents = (value.to_d * 100).to_i
  end
end
