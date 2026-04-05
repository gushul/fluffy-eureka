every '0 3 1 * *' do
  rake 'audit_logs:rotate_partitions'
end
