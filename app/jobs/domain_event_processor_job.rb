class DomainEventProcessorJob < ApplicationJob
  queue_as :events

  SUBSCRIBERS = {
    "order.completed"        => [Subscribers::NotificationSubscriber,
                                 Subscribers::ReconciliationSubscriber],
    "order.refund_requested" => [Subscribers::NotificationSubscriber,
                                 Subscribers::RefundWorkflowSubscriber],
    "order.refunded"         => [Subscribers::NotificationSubscriber,
                                 Subscribers::ReconciliationSubscriber],
    "order.refund_failed"    => [Subscribers::NotificationSubscriber,
                                 Subscribers::AlertSubscriber],
  }.freeze

  def perform
    DomainEvent.pending.find_each do |event|
      process(event)
    end
  end

  private

  def process(event)
    event.update!(status: "processing", attempts: event.attempts + 1)

    subscribers = SUBSCRIBERS.fetch(event.event_type, [])
    subscribers.each { |sub| sub.call(event.payload) }

    event.update!(status: "done", processed_at: Time.current)
  rescue => e
    event.update!(status: "failed", last_error: e.message)
  end
end
