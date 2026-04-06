module Api
  module V1
    class AccountsController < ApplicationController
      before_action :set_user

      # GET /api/v1/users/:user_id/account
      def show
        account = @user.account
        render json: account_json(account), status: :ok
      end

      # GET /api/v1/users/:user_id/account/transactions
      def transactions
        txns = @user.account.account_transactions.order(created_at: :desc)
        render json: txns.map { |t| transaction_json(t) }, status: :ok
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      end

      # TODO: move to jbuilder or serializer
      def account_json(account)
        {
          id:         account.id,
          balance:    account.balance,
          updated_at: account.updated_at,
        }
      end

      # TODO: move to jbuilder or serializer
      def transaction_json(txn)
        {
          id:         txn.id,
          kind:       txn.kind,
          amount:     txn.amount,
          order_id:   txn.order_id,
          created_at: txn.created_at,
        }
      end
    end
  end
end
