module Orders
  class Cancel < BaseService
    def initialize(order: order)
      @order = order
    end

    def call
      return failure("Cannot complete order in status '#{@order.status}'") unless @order.can_cancel?

     ActiveRecord::Base.transaction do
        # Pessimistic lock — prevents race condition on balance
        # SELECT * FROM accounts WHERE id = ? FOR UPDATE
        account = @order.user.account.lock!

        # Validate balance INSIDE the lock (state may have changed)
        if account.balance_cents < @order.amount_cents
          raise InsufficientFundsError, "Insufficient funds: " \
            "balance #{account.balance} < order amount #{@order.amount}"
        end

        # Deduct balance
        account.update!(balance_cents: account.balance_cents - @order.amount_cents)

        # Append-only ledger entry (negative = money leaving account)
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

        Result.new(success?: true, order: @order, error: nil)
      end

      ActiveRecord::Base.transaction do
        account = @order.user.account.lock!

        account.update!(balance: account.balance + @order.amount)

        @order.transactions.create!(
          account: account,
          amount: -@order.amount,
          kind: :storno
        )

        @order.update!(status: :cancelled)
      end

      @order
      sucess
    end
  end
end
