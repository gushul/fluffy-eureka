class CreateDomainEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :domain_events do |t|
      t.string   :event_type,    null: false

      t.string   :source_type,   null: false
      t.bigint   :source_id,     null: false

      t.jsonb    :payload,       null: false, default: {}
      t.string   :status,        null: false, default: "pending"
      t.integer  :attempts,      null: false, default: 0
      t.text     :last_error
      t.datetime :processed_at

      t.timestamps
    end

    # maybe redundant, but it can speed up queries for events
    add_index :domain_events, [:source_type, :source_id] 
    add_index :domain_events, [:status, :created_at]
    add_index :domain_events, :event_type
  end
end
