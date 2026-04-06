namespace :audit_logs do
  task rotate_partitions: :environment do
    conn = ActiveRecord::Base.connection

    now = Time.now.utc
    next_month = now.next_month.beginning_of_month
    old_month  = (now - 2.months).beginning_of_month

    # create next partition
    conn.execute <<~SQL
      CREATE TABLE IF NOT EXISTS audit_logs_#{next_month.strftime('%Y_%m')}
      PARTITION OF audit_logs
      FOR VALUES FROM ('#{next_month}') TO ('#{next_month.next_month}');
    SQL

    puts "Created partition for #{next_month.strftime('%Y-%m')}"

    # rotate old partition
    table = "audit_logs_#{old_month.strftime('%Y_%m')}"

    begin
      conn.execute "DROP TABLE IF EXISTS #{table};"
      puts "Dropped partition #{table}"
    rescue => e
      puts "Failed to drop #{table}: #{e.message}"
    end
  end
end
