class CreateAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :account_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.bigint :amount_cents, null: false
      t.integer :kind, null: false

      t.datetime :created_at, null: false
    end

   add_check_constraint :account_transactions,
      "kind IN ('charge', 'reversal')",
      name: "account_transactions_kind_check"
  end
end
