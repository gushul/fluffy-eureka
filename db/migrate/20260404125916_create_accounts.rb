class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint     :balance_cents, null: false, default: 0
      t.datetime   :deleted_at

      # Optimistic lock — protects against concurrent status reads
      t.integer    :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :accounts, :deleted_at
    add_check_constraint :accounts, "balance_cents >= 0", name: "account_balance_positive"
  end
end
