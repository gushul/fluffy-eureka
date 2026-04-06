module Orders
  class ProcessRefundService < BaseService
    ACTION = "order.refunded"
    FAILED_ACTION = "order.refund_failed"

    def initialize(order:, actor: nil, metadata: {})
      @order = order
      @actor = actor || @order.user
      @metadata = metadata
    end

    def call(idempotency_key: nil)
      with_idempotency(idempotency_key) do
        Rails.logger.info "Processing refund for order_id=#{@order.id}"

        validation_result = validate_transition!
        return validation_result unless validation_result.success?

        begin
          ActiveRecord::Base.transaction do
            @status_before  = @order.status
            @balance_before = @order.user.account.balance_cents

            # PRD 5.356
            @order.start_refund_processing!

            # PRD 5.357
            account = @order.user.account.lock!

            # PRD 5.253 Reconciliation check
            ledger_sum = account.account_transactions.reload.sum(:amount_cents)
            if account.balance_cents != ledger_sum
              raise "Balance discrepancy detected"
            end

            # PRD 5.358: Increment balance
            account.update!(balance_cents: account.balance_cents + @order.amount_cents)

            # PRD 5.359: Ledger record
            AccountTransaction.create!(
              account:      account,
              order:        @order,
              amount_cents: @order.amount_cents,
              kind:         "reversal",
              description:  "Refund for order ##{@order.id}"
            )

            # PRD 5.360-361
            @order.update!(refunded_at: Time.current)
            @order.complete_refund!

            audit_log = create_audit_log
            publish_events(ACTION, audit_log)

            success(@order)
          end
        rescue => e
          Rails.logger.error "DEBUG: ProcessRefundService failed: #{e.message}"
          handle_failure(e.message)
          raise e
        end
      end
    rescue ActiveRecord::StaleObjectError
      failure("Order was modified concurrently")
    rescue => e
      Rails.logger.error "DEBUG: Service failed with #{e.message}"
      failure(e.message)
    end

    private

    def validate_transition!
      unless @order.may_start_refund_processing?
        return failure("Cannot process refund from status '#{@order.status}'")
      end

      success(nil)
    end

    def handle_failure(error_message)
      ActiveRecord::Base.transaction(requires_new: true) do
        @order.reload # ensure we have fresh state
        if @order.may_fail_refund?
          @order.fail_refund!
          audit_log = AuditLog.create!(
            user:       @order.user,
            actor:      @actor,
            entity:      @order,
            action:      FAILED_ACTION,
            audit_changes: {
              status: [ @status_before, @order.status ],
              error:  [ nil, error_message ],
            }
          )
          publish_events(FAILED_ACTION, audit_log)
        end
      end
    end

    def publish_events(action, audit_log)
      DomainEvent.publish(action, source: @order)
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
