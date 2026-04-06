module Orders
  class CancelService < BaseService
    ACTION = "order.cancelled"

    def initialize(order:, actor: nil, metadata: {})
      @order = order
      @actor = actor || @order.user
      @metadata = metadata
    end

    def call(idempotency_key: nil)
      with_idempotency(idempotency_key) do
        Rails.logger.info "Starting order cancellation for order_id=#{@order.id}"

        validation_result = validate_transition!
        return validation_result unless validation_result.success?

        ActiveRecord::Base.transaction do
          @status_before = @order.status
          account = @order.user.account.lock!
          @balance_before = account.balance_cents

          if @status_before == "success"
            ledger_sum = account.account_transactions.reload.sum(:amount_cents)
            if account.balance_cents != ledger_sum
              return failure("Balance discrepancy detected (Balance: #{account.balance_cents}, Ledger: #{ledger_sum})")
            end

            # Reversal
            account.update!(balance_cents: account.balance_cents + @order.amount_cents)
            at = AccountTransaction.create!(
              account:      account,
              order:        @order,
              amount_cents: @order.amount_cents,
              kind:         "reversal",
              description:  "Reversal for cancelled order ##{@order.id}"
            )
          end

          @order.cancel!

          audit_log = create_audit_log
          publish_events(audit_log)

          success(@order)
        end
      end
    rescue ActiveRecord::StaleObjectError
      failure("Order was modified concurrently")
    rescue => e
      failure(e.message)
    end

    private

    def validate_transition!
      unless @order.may_cancel?
        return failure("Cannot cancel order from status '#{@order.status}'")
      end

      success(nil)
    end

    def publish_events(audit_log)
      DomainEvent.publish(ACTION, source: @order)
      OutboxEvent.create!(event_type: "audit_log_created", payload: audit_log.as_json)
    end

    def create_audit_log
      changes = { status: [ @status_before, @order.status ] }
      if @status_before == "success"
        changes[:balance_cents] = [ @balance_before, @order.user.account.balance_cents ]
      end

      AuditLog.create!(
        user:          @order.user,
        actor:         @actor,
        entity:        @order,
        action:        ACTION,
        audit_changes: changes,
        ip_address:    @metadata[:ip_address],
        user_agent:    @metadata[:user_agent]
      )
    end
  end
end
