module Orders
  class RequestRefundService < BaseService
    ACTION = "order_request_refund".freeze
    def initialize(order:, actor:, reason:)
      @order = order
      @actor = actor
      @reason = reason
    end

    def call
      Rails.logger.info "Starting order request refund for order_id=#{@order.id}"

      validation_result = validate_transition!
      return validation_result unless validation_result.success?

      ActiveRecord::Base.transaction do

        @status_before  = @order.status

        @order.update!(refund_reason: @reason)
        @order.request_refund!
        # Pessimistic Locking
        # SELECT * FROM accounts WHERE id = ? FOR UPDATE
        account = @order.user.account.lock!

        @order.complete!

        create_audit_log
        publish_domain_event

        Rails.logger.info "Successfully completed order_id=#{@order.id}"
        success(@order)
      end
    rescue ActiveRecord::StaleObjectError
      error_msg = "Order #{@order.id} was modified concurrently during completion"
      Rails.logger.warn error_msg
      failure(error_msg)
    rescue => e
      error_msg = "Unexpected error completing order #{@order.id}: #{e.message}"
      Rails.logger.error error_msg
      Rails.error.report(e)
      failure(error_msg)
    end

    private

    def validate_transition!
      unless @order.may_request_refund?
        error_msg = "Cannot request refund for order in  #{@order.id} in status '#{@order.status}'"
        Rails.logger.warn error_msg
        return failure(error_msg)
      end

      success(nil)
    end

    def publish_domain_event
      DomainEvent.publish(ACTION, source: @order, payload: { reason: @reason })
    end

    def create_audit_log
      # TODO: DRY; IMHO move to lib
      AuditLog.create!(
        actor:           @actor,
        entity:          @order,
        action:          ACTION,
        changes: {
          status:        [@status_before,  @order.status],
        },
        ip:              request.remote_ip,
        user_agent:      request.user_agent
      )

      OutboxEvent.create!(
        event_type: "audit_log_created",
        payload: audit.attributes
      )
    end
  end
end
