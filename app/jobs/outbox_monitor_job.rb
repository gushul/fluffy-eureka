class OutboxMonitorJob < ApplicationJob
  queue_as :monitoring

  ALERT_THRESHOLD = 0

  def perform
    stuck_count = OutboxEvent
      .where(processed_at: nil)
      .where("attempts >= ?", OutboxEvent::MAX_ATTEMPTS)
      .count

    if stuck_count > ALERT_THRESHOLD
      AlertService.trigger(
        title:    "OutboxJob: #{stuck_count} events stuck (max attempts reached)",
        severity: :critical
      )
    end
  end
end
