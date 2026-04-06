module Orders
  class CompleteService < BaseService
    ACTION = "order.completed"

    def initialize(order:, actor: nil, metadata: {})
      @order = order
      @actor = actor || @order.user
      @metadata = metadata
    end

    def call(idempotency_key: nil)
      with_idempotency(idempotency_key) do
        Rails.logger.info "Starting order completion for order_id=#{@order.id}"

        validation_result = validate_transition!
        return validation_result unless validation_result.success?

        ActiveRecord::Base.transaction do
          # Pessimistic Locking
          account = @order.user.account.lock!

          # PRD 5.253 Reconciliation check
          ledger_sum = account.account_transactions.reload.sum(:amount_cents)
          if account.balance_cents != ledger_sum
            return failure("Balance discrepancy detected: account=#{account.balance_cents}, ledger=#{ledger_sum}")
          end

          if account.balance_cents < @order.amount_cents
            return failure("Insufficient funds")
          end

          @balance_before = account.balance_cents
          @status_before  = @order.status

          # Update balance
          account.update!(balance_cents: account.balance_cents - @order.amount_cents)

          # Ledger record
          AccountTransaction.create!(
            account:      account,
            order:        @order,
            amount_cents: -@order.amount_cents,
            kind:         "charge",
            description:  "Charge for order ##{@order.id}"
          )

          # Optimistic lock guard on transition
          @order.complete!

          audit_log = create_audit_log
          publish_events(audit_log)

          success(@order)
        end
      end
    rescue ActiveRecord::StaleObjectError
      failure("Order was modified concurrently")
    rescue => e
      puts "DEBUG: service failed with error: #{e.message}"
      Rails.logger.error "Error completing order #{@order.id}: #{e.message}"
      failure(e.message)
    end

    private

    def validate_transition!
      unless @order.may_complete?
        return failure("Cannot complete order from status '#{@order.status}'")
      end

      success(nil)
    end

    def publish_events(audit_log)
      # PRD 5.291-292
      DomainEvent.publish(ACTION, source: @order)
      OutboxEvent.create!(event_type: "audit_log_created", payload: audit_log.as_json)
    end

    def create_audit_log
      AuditLog.create!(
        user:       @order.user,
        actor:      @actor,
        entity:      @order,
        action:      ACTION,
        audit_changes: {
          status:        [ @status_before,  @order.status ],
          balance_cents: [ @balance_before, @order.user.account.balance_cents ],
        },
        ip_address: @metadata[:ip_address],
        user_agent: @metadata[:user_agent]
      )
    end
  end
end
