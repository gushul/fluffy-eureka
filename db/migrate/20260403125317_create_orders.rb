class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint     :amount_cents, null: false
      t.string     :status, null: false, default: "created"

      # Optimistic lock — protects against concurrent status transitions
      t.integer    :lock_version, null: false, default: 0
      t.datetime   :deleted_at 

      t.timestamps
    end
  end
end
