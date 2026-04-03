module Orders
  class Complete
    Result = Data.define(:success?, :order, :error)

    def initialize(order)
      @order = order
    end

    def call
      raise InvalidTransitionError unless @order.can_complete?
      Result.new(success?: false, order: @order.reload, error: e.message) unless @order.may_mark_successful?

      ActiveRecord::Base.transaction do
        account = @order.user.account.lock!

        account.update!(balance: account.balance - @order.amount)

        @order.transactions.create!(
          account: account,
          amount: @order.amount,
          kind: :debit
        )

        @order.update!(status: :success)
      end

      @order
    end
  end
end
