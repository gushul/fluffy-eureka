class CreateAccountTransactions < ActiveRecord::Migration[8.1]
  def change
    # for PostgreSQL, but sqllite doesn't support enums, so we also add a check constraint
    # create_enum :account_transaction_kind, ["charge", "reversal"]
    #
    create_table :account_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.bigint     :amount_cents, null: false
      t.text       :description

      # for PostgreSQL, but sqllite doesn't support enums, so we also add a check constraint
      # t.enum :kind, enum_type: :account_transaction_kind, null: false
      t.string     :kind, null: false # for sqllite

      t.datetime   :deleted_at
      t.datetime   :created_at, null: false
    end

    add_index :account_transactions, :deleted_at

    # TODO remove when use PostgreSQL and use enum type
    add_check_constraint :account_transactions,
      "kind IN ('charge', 'reversal')",
      name: "account_transactions_kind_check"
  end
end
