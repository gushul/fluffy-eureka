class OutboxJob < ApplicationJob
  BATCH_SIZE = 100

  queue_as :outbox

  def perform
    loop do
      events = OutboxEvent
        .where(processed_at: nil)
        .limit(BATCH_SIZE)
        .lock("FOR UPDATE SKIP LOCKED") # can run from multiple workers without conflicts

      break if events.empty?

      events.each do |event|
        begin
          Kafka::Producers::GenericProducer.deliver(topic: event.event_type, event: event)
        rescue => e
          event.update!(error: e.message)
          next
        end
      end

      Kafka::Producers::GenericProducer.flush

      events.each do |event|
        event.update!(processed_at: Time.current)
      end
    end
  end
end
