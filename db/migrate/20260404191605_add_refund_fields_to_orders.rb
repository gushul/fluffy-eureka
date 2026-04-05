class AddRefundFieldsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :refund_reason, :string
    add_column :orders, :refunded_at,   :datetime
  end
end
