# == Schema Information
#
# Table name: account_transactions
#
#  id           :bigint           not null, primary key
#  amount_cents :bigint           not null
#  deleted_at   :datetime
#  description  :text
#  kind         :enum             not null
#  created_at   :datetime         not null
#  account_id   :bigint           not null
#  order_id     :bigint           not null
#
# Indexes
#
#  index_account_transactions_on_account_id  (account_id)
#  index_account_transactions_on_deleted_at  (deleted_at)
#  index_account_transactions_on_order_id    (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (order_id => orders.id)
#

class AccountTransaction < ApplicationRecord
  include SoftDeletable

  KINDS = [
    CHARGE = 'charge',
    REVERSAL = 'reversal',
  ].freeze

  belongs_to :account
  belongs_to :order

  validates :amount_cents, presence: true
  validates :kind, inclusion: { in: KINDS }

  validate :account_and_order_belong_to_same_user

  # Immutable — this records must never be changed or deleted after creation
  # before_update  { raise ImmutableRecordError, "AccountTransaction records are immutable" } - old code

  before_update :guard_immutability # can be soft deleted, but not updated
  before_destroy { raise ImmutableRecordError, "AccountTransaction records cannot be deleted" }

  def amount
    amount_cents / 100.0
  end

  private

  def guard_immutability
    # changed — list of attributes that differ from DB value
    forbidden_changes = changed - [ "deleted_at" ]
    if forbidden_changes.any?
      raise ImmutableRecordError,
        "AccountTransaction is immutable. Attempted to change: #{forbidden_changes.join(', ')}"
    end
  end

  def account_and_order_belong_to_same_user
    return if account.blank? || order.blank?

    unless account.user_id == order.user_id
      errors.add(:account, "must belong to the same user as the order")
    end
  end
end
