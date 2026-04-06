module Api
  module V1
    class OrdersController < ApplicationController
      before_action :set_user
      before_action :set_order, only: %i[show complete cancel request_refund retry_refund]

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
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # PATCH /api/v1/users/:user_id/orders/:id/complete
      def complete
        result = Orders::CompleteService.new(
          order: @order,
          actor: @user,
          metadata: request_metadata
        ).call(idempotency_key: idempotency_key)

        render_result(result)
      end

      # PATCH /api/v1/users/:user_id/orders/:id/cancel
      def cancel
        result = Orders::CancelService.new(
          order: @order,
          actor: @user,
          metadata: request_metadata
        ).call(idempotency_key: idempotency_key)

        render_result(result)
      end

      # PATCH /api/v1/users/:user_id/orders/:id/request_refund
      def request_refund
        result = Orders::RequestRefundService.new(
          order: @order,
          actor: @user,
          reason: params[:reason],
          metadata: request_metadata
        ).call(idempotency_key: idempotency_key)

        render_result(result)
      end

      # PATCH /api/v1/users/:user_id/orders/:id/retry_refund
      def retry_refund
        result = Orders::RetryRefundService.new(
          order: @order,
          actor: @user
        ).call

        render_result(result)
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      end

      def set_order
        @order = @user.orders.find(params[:id])
      end

      def idempotency_key
        request.headers["Idempotency-Key"]
      end

      def request_metadata
        {
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
        }
      end

      def render_result(result)
        if result.success?
          render json: order_json(result.data), status: :ok
        else
          render json: { error: result.errors.join(", ") }, status: :unprocessable_entity
        end
      end

      def order_json(order)
        {
          id:            order.id,
          status:        order.status,
          amount:        order.amount,
          description:   order.description,
          refund_reason: order.refund_reason,
          refunded_at:   order.refunded_at,
          created_at:    order.created_at,
          updated_at:    order.updated_at,
        }
      end

      def orders_json(orders)
        orders.map { |o| order_json(o) }
      end
    end
  end
end
