module Orders
  class CancelService
    def initialize(order)
      @order = order
    end

    def call
      raise InvalidTransitionError unless @order.can_cancel?

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
    end
  end
end
