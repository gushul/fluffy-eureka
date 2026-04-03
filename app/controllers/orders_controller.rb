class OrdersController < ApplicationController
  def create
    order = Order.create!(user_id: params[:user_id], amount: params[:amount], status: :created)
    render json: order, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def complete
    order = Order.find(params[:id])
    Orders::CompleteService.new(order).call
    render json: order, status: :ok
  rescue InvalidTransitionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  def cancel
    order = Order.find(params[:id])
    Orders::CancelService.new(order).call
    render json: order, status: :ok
  rescue InvalidTransitionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
