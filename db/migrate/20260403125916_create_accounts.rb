class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :balance_cents, null: false, default: 0
      # Optimistic lock — protects against concurrent status reads
      t.integer :lock_version, null: false, default: 0

      t.timestamps
      
      t.check_constraint "balance >= 0"
    end
  end
end
