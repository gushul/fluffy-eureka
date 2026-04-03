module Orders
  class CompleteService < BaseService
    def initialize(order:)
      @order = order
    end

    def call
      Rails.logger.info "Starting order completion for order_id=#{@order.id}"

      validation_result = validate_transition!
      return validation_result unless validation_result.success?

      ActiveRecord::Base.transaction do
        # Pessimistic Locking
        # SELECT * FROM accounts WHERE id = ? FOR UPDATE
        account = @order.user.account.lock!

        if account.balance_cents < @order.amount_cents
          error_msg = "Insufficient funds for order #{@order.id}: " \
                      "balance #{account.balance_cents} < order amount #{@order.amount_cents}"
          Rails.logger.warn error_msg
          return failure(error_msg)
        end

        # Account balance substraction
        account.update!(balance_cents: account.balance_cents - @order.amount_cents)

        AccountTransaction.create!(
          account:      account,
          order:        @order,
          amount_cents: -@order.amount_cents,
          kind:         "charge",
          description:  "Charge for order ##{@order.id}"
        )

        # Transition status — optimistic lock on order protects
        # against two concurrent requests completing the same order
        @order.complete!

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
      unless @order.may_complete?
        error_msg = "Cannot complete order #{@order.id} in status '#{@order.status}'"
        Rails.logger.warn error_msg
        return failure(error_msg)
      end

      success(nil)
    end
  end
end
