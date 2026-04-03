class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :balance, precision: 15, scale: 2, null: false, default: 0

      t.timestamps
      
      t.check_constraint "balance >= 0"
    end
  end
end
