require "rails_helper"
 
RSpec.describe Subscribers::NotificationSubscriber do
  let(:user)    { create(:user) }
  let(:order)   { create(:order, user: user) }
 
  let(:payload) do
    { "order_id" => order.id, "user_id" => user.id, "amount" => 49.99 }
  end
 
  subject(:call) { described_class.call(payload.merge("event_type" => event_type)) }
 
  shared_examples "enqueues email" do |mailer_method|
    it "enqueues #{mailer_method} email" do
      expect { call }.to have_enqueued_mail(OrderMailer, mailer_method)
    end
  end
 
  describe "order.completed" do
    let(:event_type) { "order.completed" }
    include_examples "enqueues email", :completed
  end
 
  describe "order.refund_requested" do
    let(:event_type) { "order.refund_requested" }
    include_examples "enqueues email", :refund_requested
  end
 
  describe "order.refunded" do
    let(:event_type) { "order.refunded" }
    include_examples "enqueues email", :refunded
  end
 
  describe "order.refund_failed" do
    let(:event_type) { "order.refund_failed" }
    include_examples "enqueues email", :refund_failed
  end
 
  describe "unknown event type" do
    let(:event_type) { "order.unknown" }
 
    it "does not raise" do
      expect { call }.not_to raise_error
    end
 
    it "does not enqueue any email" do
      expect { call }.not_to have_enqueued_mail
    end
  end
end
