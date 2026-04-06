module FinanceTestHelpers
  def top_up_balance(account, amount_cents)
    return if amount_cents <= 0

    system_order = create(:order, user: account.user, amount_cents: amount_cents, status: "success", description: "Test Top-up")
    account.account_transactions.create!(
      order:        system_order,
      amount_cents: amount_cents,
      kind:         "reversal",
      description:  "Manual test top-up"
    )
    account.update_column(:balance_cents, account.account_transactions.reload.sum(:amount_cents))
    account.reload
  end

  def clear_balance(account)
    AccountTransaction.where(account_id: account.id).delete_all
    account.update_column(:balance_cents, 0)
    account.reload
  end
end
