class AlertService
  def self.trigger(title:, payload: {})
    # PRD 7.579
    puts "ALERT: #{title}"
    puts "PAYLOAD: #{payload.inspect}"
  end
end
