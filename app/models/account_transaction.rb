class AccountTransaction < ApplicationRecord
  KINDS = [
    CHARGE = 'charge',
    REVERSAL = 'reversal',
  ].freeze

  belongs_to :account
  belongs_to :order

  validates :amount_cents, presence: true
  validates :kind, inclusion: { in: KINDS.values }

  # Immutable — financial records must never be altered
  before_update  { raise ImmutableRecordError, "AccountTransaction records are immutable" }
  before_destroy { raise ImmutableRecordError, "AccountTransaction records cannot be deleted" }

  def amount
    amount_cents / 100.0
  end
end
