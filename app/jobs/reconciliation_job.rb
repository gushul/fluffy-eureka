class ReconciliationJob < ApplicationJob
  queue_as :monitoring

  def perform
    Account.find_each do |account|
      ledger_balance = account.account_transactions.sum(:amount_cents)

      if account.balance_cents != ledger_balance
        Rails.logger.critical "Reconciliation failure: Account ##{account.id} balance discrepancy! " \
                             "Balance cents: #{account.balance_cents}, Ledger sum: #{ledger_balance}"

        # TODO:
        #
        # AlertService.trigger(
        #   title: "Account balance discrepancy",
        #   details: { account_id: account.id, balance: account.balance_cents, ledger: ledger_balance },
        #   severity: :critical
        # )
      end
    end
  end
end
