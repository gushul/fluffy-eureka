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
class AuditLog < ApplicationRecord
  self.primary_key = :id
  self.implicit_order_column = "created_at"
end

class Order < ApplicationRecord
  include AASM
  include SoftDeletable

  belongs_to :user
  has_many   :account_transactions

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :status, presence: true

  aasm column: :status do
    state :created,           initial: true
    state :success
    state :refund_requested
    state :refund_processing
    state :refunded
    state :refund_failed
    state :cancelled

    event :complete do
      transitions from: :created, to: :success
    end

    # created → cancelled: only without financial impact
    # success → cancelled: with financial impact (reversal)
    event :cancel do
      transitions from: [ :created, :success ], to: :cancelled
    end

    # success → refund_requested: user requests refund
    event :request_refund do
      transitions from: :success, to: :refund_requested
    end

    # refund_requested → refund_processing: begin refund process (e.g. call payment gateway API)
    event :start_refund_processing do
      transitions from: :refund_requested, to: :refund_processing
    end

    # refund_processing → refunded: refund successful, account balance should be updated
    event :complete_refund do
      transitions from: :refund_processing, to: :refunded
    end

    # refund_processing → refund_failed: something went wrong during refund process (e.g. payment gateway API error)
    event :fail_refund do
      transitions from: [ :refund_requested, :refund_processing ], to: :refund_failed
    end

    # refund_failed → refund_requested: retry refund process after failure (e.g. transient payment gateway issue)
    event :retry_refund do
      transitions from: :refund_failed, to: :refund_requested
    end
  end

  # TODO: move to drapper or decorator if we want to keep the model focused on persistence
  def amount
    amount_cents / 100.0
  end

  def amount=(value)
    self.amount_cents = (value.to_d * 100).to_i
  end
end
