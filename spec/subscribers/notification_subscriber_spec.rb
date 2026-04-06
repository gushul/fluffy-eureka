require "rails_helper"

RSpec.describe Subscribers::NotificationSubscriber do
  subject(:call) { described_class.call(payload) }

  let(:user)    { create(:user) }
  let(:order)   { create(:order, user: user) }

  let(:payload) do
    {
      "source_type" => "Order",
      "source_id"   => order.id,
      "event_type"  => event_type,
      "payload"     => { "amount" => 49.99 },
    }
  end


  shared_examples "enqueues email" do |mailer_method|
    it "enqueues #{mailer_method} email" do
      expect { call }.to have_enqueued_mail(OrderMailer, mailer_method)
    end
  end

  describe "order.completed" do
    let(:event_type) { "order.completed" }

    it_behaves_like "enqueues email", :completed
  end

  describe "order.refund_requested" do
    let(:event_type) { "order.refund_requested" }

    it_behaves_like "enqueues email", :refund_requested
  end

  describe "order.refunded" do
    let(:event_type) { "order.refunded" }

    it_behaves_like "enqueues email", :refunded
  end

  describe "order.refund_failed" do
    let(:event_type) { "order.refund_failed" }

    it_behaves_like "enqueues email", :refund_failed
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
