class OutboxJob < ApplicationJob
  BATCH_SIZE = 100

  queue_as :outbox

  def perform
    loop do
      events = OutboxEvent
        .where(processed_at: nil)  # ← не трогаем failed
        .where("attempts < ?", OutboxEvent::MAX_ATTEMPTS) 
        .limit(BATCH_SIZE)
        .lock("FOR UPDATE SKIP LOCKED")

      break if events.empty?

      successfully_delivered_ids = []

      events.each do |event|
        Kafka::Producers::GenericProducer.deliver(
          topic: event.event_type,
          event: event
        )
        successfully_delivered_ids << event.id
      rescue => e
        event.update!(error: e.message, attempts: event.attempts + 1)
      end

      Kafka::Producers::GenericProducer.flush

      OutboxEvent
        .where(id: successfully_delivered_ids)
        .update_all(processed_at: Time.current)
    end
  end
end
