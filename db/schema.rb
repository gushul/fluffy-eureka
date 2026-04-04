# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_03_130218) do
  create_table "account_transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "kind", null: false
    t.integer "order_id", null: false
    t.index ["account_id"], name: "index_account_transactions_on_account_id"
    t.index ["deleted_at"], name: "index_account_transactions_on_deleted_at"
    t.index ["order_id"], name: "index_account_transactions_on_order_id"
    t.check_constraint "kind IN ('charge', 'reversal')", name: "account_transactions_kind_check"
  end

  create_table "accounts", force: :cascade do |t|
    t.bigint "balance_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["deleted_at"], name: "index_accounts_on_deleted_at"
    t.index ["user_id"], name: "index_accounts_on_user_id"
    t.check_constraint "balance_cents >= 0", name: "account_balance_positive"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "lock_version", default: 0, null: false
    t.string "status", default: "created", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "account_transactions", "accounts"
  add_foreign_key "account_transactions", "orders"
  add_foreign_key "accounts", "users"
  add_foreign_key "orders", "users"
end
