class AccountsController < ApplicationController
  def show
    account = Account.includes(:transactions).find(params[:id])
    render json: account.as_json(include: :transactions)
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
