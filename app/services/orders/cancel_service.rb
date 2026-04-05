module Orders
  class CancelService < BaseService
    ACTION = "order_canceled".freeze
    def initialize(order:)
      @order = order
    end

    def call
      Rails.logger.info "Starting order cancellation for order_id=#{@order.id}"

      validation_result = validate_transition!
      return validation_result unless validation_result.success?

      ActiveRecord::Base.transaction do
        if @order.success?
          # Pessimistic Locking
          # SELECT * FROM accounts WHERE id = ? FOR UPDATE
          account = @order.user.account.lock!


          # Account balance substraction
          account.update!(balance_cents: account.balance_cents + @order.amount_cents)


          AccountTransaction.create!(
            account:      account,
            order:        @order,
            amount_cents: @order.amount_cents,
            kind:         "reversal",
            description:  "Reversal for cancelled order ##{@order.id}"
          )

          Rails.logger.info "Applied reversal for order_id=#{@order.id}, " \
            "returned #{@order.amount_cents} cents to account #{account.id}"
        end

        # Optimistic lock on order prevents double-cancel
        @order.cancel!

        create_audit_log
        publish_domain_event

        Rails.logger.info "Successfully cancelled order_id=#{@order.id}"
        success(@order)
      end
    rescue ActiveRecord::StaleObjectError
      error_msg = "Order #{@order.id} was modified concurrently during cancellation"
      Rails.logger.warn error_msg
      failure(error_msg)
    rescue => e
      error_msg = "Unexpected error cancelling order #{@order.id}: #{e.message}"
      Rails.logger.error error_msg
      Rails.error.report(e)
      failure(error_msg)
    end

    private

    def validate_transition!
      unless @order.may_cancel?
        error_msg = "Cannot cancel order #{@order.id} in status '#{@order.status}'"
        Rails.logger.warn error_msg
        return failure(error_msg)
      end

      success(nil) # Validation passed
    end

    def publish_domain_event
      DomainEvent.publish(ACTION, source: @order)
    end

    def create_audit_log
      # TODO: DRY; IMHO move to lib
      AuditLog.create!(
        actor:           @actor,
        entity:          @order,
        action:          ACTION,
        changes: {
          status:        [status_before,  @order.status],
          balance_cents: [balance_before, account.balance_cents]
        },
        ip:              request.remote_ip,
        user_agent:      request.user_agent
      )
    end
  end
end
