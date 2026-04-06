require "rails_helper"

RSpec.describe ReconciliationSubscriber do
  subject(:call) { described_class.call(payload) }

  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user, amount_cents: 4999) }

  let(:payload) do
    {
      "source_type" => "Order",
      "source_id"   => order.id,
      "event_type"  => "order.completed",
      "payload"     => { "amount" => 49.99 },
    }
  end


  it "creates a reconciliation log entry" do
    expect { call }.to change(ReconciliationLog, :count).by(1)
  end

  it "stores correct attributes" do
    call
    log = ReconciliationLog.last
    expect(log.order_id).to    eq(order.id)
    expect(log.event_type).to  eq("order.completed")
    expect(log.amount).to      eq(49.99)
    expect(log.logged_at).to   be_present
  end

  describe "when ReconciliationLog.create! fails" do
    before do
      allow(ReconciliationLog).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
    end

    it "raises so DomainEventProcessorJob marks event as failed" do
      expect { call }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
