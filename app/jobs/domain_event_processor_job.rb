class DomainEventProcessorJob < ApplicationJob
  queue_as :events

  def perform
    DomainEvent.pending.find_each do |event|
      process(event)
    end
  end

  private

  def process(event)
    event.update!(status: "processing", attempts: event.attempts + 1)

    subscribers = case event.event_type
    when "order.completed"
                    [ NotificationSubscriber, ReconciliationSubscriber ]
    when "order.cancelled"
                    [ NotificationSubscriber ]
    when "order.refund_requested"
                    [ NotificationSubscriber, RefundWorkflowSubscriber ]
    when "order.refunded"
                    [ NotificationSubscriber, ReconciliationSubscriber ]
    when "order.refund_failed"
                    [ NotificationSubscriber, AlertSubscriber ]
    when "order.refund_retried"
                    [ NotificationSubscriber ]
    else
                    []
    end

    payload = {
      "event_type"  => event.event_type,
      "source_id"    => event.source_id,
      "source_type"  => event.source_type,
      "event_id"     => event.event_id,
      "data"         => event.payload,
    }

    subscribers.each do |subscriber|
      subscriber.call(payload)
    end

    event.update!(status: "done", processed_at: Time.current)
  rescue => e
    event.update!(status: "failed", last_error: e.message)
  end
end
