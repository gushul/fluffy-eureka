module Api
  module V1
    class OrdersController < ApplicationController
      before_action :set_user
      before_action :set_order, only: %i[show complete cancel]

      # GET /api/v1/users/:user_id/orders
      def index
        orders = @user.orders.order(created_at: :desc)
        render json: orders_json(orders), status: :ok
      end

      # GET /api/v1/users/:user_id/orders/:id
      def show
        render json: order_json(@order), status: :ok
      end

      # POST /api/v1/users/:user_id/orders
      def create
        order = @user.orders.create!(
          amount_cents: (params[:amount].to_d * 100).to_i,
          description:  params[:description]
        )
        render json: order_json(order), status: :created
      end

      # PATCH /api/v1/users/:user_id/orders/:id/complete
      def complete
        result = Orders::CompleteService.call(order: @order)

        if result.success?
          render json: order_json(result.data), status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/users/:user_id/orders/:id/cancel
      def cancel
        result = Orders::CancelService.call(order: @order)

        if result.success?
          render json: order_json(result.data), status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      # TODO DRY
      def set_user
        @user = User.find(params[:user_id])
      end

      def set_order
        @order = @user.orders.find(params[:id])
      end

      # TODO move to jbuilder or serializer
      def order_json(order)
        {
          id:          order.id,
          status:      order.status,
          amount:      order.amount,
          description: order.description,
          created_at:  order.created_at,
          updated_at:  order.updated_at,
        }
      end

      # TODO move to jbuilder or serializer
      def orders_json(orders)
        orders.map { |o| order_json(o) }
      end
    end
  end
end
