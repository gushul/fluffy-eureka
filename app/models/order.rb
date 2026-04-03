class Order < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy

  enum :status, { created: 0, success: 1, cancelled: 2 }

  def can_complete? = created?
  def can_cancel?   = success?
end
