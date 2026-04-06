class CreateOutboxEvents < ActiveRecord::Migration[7.1]
  def up
    create_table :outbox_events do |t|
      t.string   :event_type,  null: false
      t.jsonb    :payload,     null: false
      t.text     :error
      t.integer  :attempts, null: false, default: 0

      t.datetime :processed_at
      t.datetime :created_at,  null: false, default: -> { "NOW()" }
    end

    add_index :outbox_events, :created_at
    add_index :outbox_events, :event_type
    create_index_for_processed_at
  end

  def down
    execute "DROP TABLE IF EXISTS outbox_events CASCADE;"
  end

  private

  def create_index_for_processed_at
    execute "CREATE INDEX IF NOT EXISTS index_outbox_unprocessed ON outbox_events (id) WHERE processed_at IS NULL;"
  end
end
