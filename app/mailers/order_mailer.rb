class OrderMailer < ApplicationMailer
  def completed(order); end
  def cancelled(order); end
  def refund_requested(order); end
  def refunded(order); end
  def refund_failed(order); end
  def refund_retried(order); end
end
