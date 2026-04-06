class CreateReconciliationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :reconciliation_logs do |t|
      t.bigint :order_id
      t.string :event_type
      t.decimal :amount
      t.datetime :logged_at

      t.timestamps
    end
  end
end
