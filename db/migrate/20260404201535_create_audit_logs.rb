class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      CREATE TABLE audit_logs (
        id            BIGSERIAL,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

        user_id       BIGINT,
        actor_type    CHARACTER VARYING NOT NULL,
        actor_id      BIGINT,

        action        CHARACTER VARYING NOT NULL,

        entity_type   CHARACTER VARYING NOT NULL,
        entity_id     BIGINT NOT NULL,

        ip_address    INET,
        user_agent    TEXT,

        changes       JSONB
      ) PARTITION BY RANGE (created_at);
    SQL

    create_partition(Date.today.beginning_of_month)

    add_indexes_for_partition(Date.today.beginning_of_month)
  end

  def down
    execute "DROP TABLE IF EXISTS audit_logs CASCADE;"
  end

  private

  def create_partition(date)
    from = date.beginning_of_month
    to   = from.next_month

    execute <<~SQL
      CREATE TABLE IF NOT EXISTS audit_logs_#{from.strftime('%Y_%m')}
      PARTITION OF audit_logs
      FOR VALUES FROM ('#{from}') TO ('#{to}');
    SQL
  end

  def add_indexes_for_partition(date)
    table = "audit_logs_#{date.strftime('%Y_%m')}"


    execute "CREATE INDEX IF NOT EXISTS #{table}_user_created_idx ON #{table} (user_id, created_at DESC);"
    execute "CREATE INDEX IF NOT EXISTS #{table}_entity_idx ON #{table} (entity_type, entity_id);"
    execute "CREATE INDEX IF NOT EXISTS #{table}_action_idx ON #{table} (action);"
    execute "CREATE INDEX IF NOT EXISTS #{table}_metadata_gin_idx ON #{table} USING GIN (changes);"
  end
end
