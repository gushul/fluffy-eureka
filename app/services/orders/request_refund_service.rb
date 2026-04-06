module Orders
  class RequestRefundService < BaseService
    ACTION = "order.refund_requested"

    def initialize(order:, reason:, actor: nil, metadata: {})
      @order = order
      @actor = actor || @order.user
      @reason = reason
      @metadata = metadata
    end

    def call(idempotency_key: nil)
      with_idempotency(idempotency_key) do
        Rails.logger.info "Starting order refund request for order_id=#{@order.id}"

        validation_result = validate_params!
        return validation_result unless validation_result.success?

        validation_result = validate_transition!
        return validation_result unless validation_result.success?

        ActiveRecord::Base.transaction do
          @status_before = @order.status

          @order.update!(refund_reason: @reason)
          @order.request_refund!

          create_audit_log
          publish_events

          success(@order)
        end
      end
    rescue ActiveRecord::StaleObjectError
      failure("Order was modified concurrently")
    rescue => e
      failure(e.message)
    end

    private

    def validate_params!
      if @reason.blank?
        return failure("Refund reason is required")
      end

      success(nil)
    end

    def validate_transition!
      unless @order.may_request_refund?
        return failure("Cannot request refund from status '#{@order.status}'")
      end

      success(nil)
    end

    def publish_events
      DomainEvent.publish(ACTION, source: @order, payload: { reason: @reason })
      OutboxEvent.create!(event_type: "audit_log_created", payload: @audit_log.as_json)
    end

    def create_audit_log
      @audit_log = AuditLog.create!(
        user:       @order.user,
        actor:      @actor,
        entity:      @order,
        action:      ACTION,
        audit_changes: {
          status:        [ @status_before, @order.status ],
          refund_reason: [ nil, @reason ],
        },
        ip_address: @metadata[:ip_address],
        user_agent: @metadata[:user_agent]
      )
    end
  end
end
