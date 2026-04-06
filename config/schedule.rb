# delete old audit log partitions and create new ones
every '0 3 1 * *' do
  rake 'audit_logs:rotate_partitions'
end

# monitor failed outbox events and alert
every 5.minutes do
  OutboxMonitorJob.perform_later
end
