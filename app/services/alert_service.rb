class AlertService
  def self.trigger(title:, payload: {})
    puts "ALERT: #{title}"
    puts "PAYLOAD: #{payload.inspect}"
  end
end
