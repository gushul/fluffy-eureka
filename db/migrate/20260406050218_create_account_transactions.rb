class CreateAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    create_enum :account_transaction_kind, ["charge", "reversal"]

    create_table :account_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.bigint     :amount_cents, null: false
      t.text       :description

      t.enum :kind, enum_type: :account_transaction_kind, null: false

      t.datetime   :deleted_at
      t.datetime   :created_at, null: false
    end

    add_index :account_transactions, :deleted_at

    # PRD 3.136: UNIQUE (order_id, kind) WHERE kind = 'charge'
    add_index :account_transactions, [:order_id, :kind],
              unique: true,
              where: "kind = 'charge'",
              name: "unique_charge_per_order"

    # PRD 3.137: UNIQUE (order_id, kind) WHERE kind = 'reversal'
    add_index :account_transactions, [:order_id, :kind],
              unique: true,
              where: "kind = 'reversal'",
              name: "unique_reversal_per_order"
  end
end
