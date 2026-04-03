class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :order

  enum :kind, { debit: 0, storno: 1 }

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
