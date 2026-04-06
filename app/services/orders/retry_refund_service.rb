module Orders
  class RetryRefundService < BaseService
    ACTION = "order.refund_retried"

    def initialize(order:, actor:)
      @order = order
      @actor = actor
    end

    def call
      return success(@order) if @order.refund_requested?

      unless @order.may_retry_refund?
        return failure("Cannot retry refund from status '#{@order.status}'")
      end

      ActiveRecord::Base.transaction do
        @status_before = @order.status

        # Transition to refund_requested
        @order.retry_refund!

        audit_log = create_audit_log
        publish_events(audit_log)

        # Enqueue background job for automatic processing
        ProcessRefundJob.perform_later(@order.id)
      end

      success(@order)
    rescue ActiveRecord::StaleObjectError
      failure("Order was modified concurrently")
    rescue => e
      failure(e.message)
    end

    private

    def publish_events(audit_log)
      DomainEvent.publish(ACTION, source: @order)
      OutboxEvent.create!(event_type: "audit_log_created", payload: audit_log.as_json)
    end

    def create_audit_log
      AuditLog.create!(
        user:          @order.user,
        actor:         @actor,
        entity:        @order,
        action:        ACTION,
        audit_changes: {
          status: [ @status_before, @order.status ],
        }
      )
    end
  end
end
