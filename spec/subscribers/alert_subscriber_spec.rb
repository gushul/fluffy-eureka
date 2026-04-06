require "rails_helper"

RSpec.describe AlertSubscriber do
  subject(:call) { described_class.call(payload) }

  let(:payload) do
    {
      "order_id" => 42,
      "user_id"  => 1,
      "reason"   => "Gateway timeout",
    }
  end


  it "triggers an alert" do
    expect(AlertService).to receive(:trigger).with(
      hash_including(title: "Refund failed for order #42")
    )
    call
  end

  it "includes payload in alert" do
    expect(AlertService).to receive(:trigger).with(
      hash_including(payload: payload)
    )
    call
  end

  describe "when AlertService raises" do
    before do
      allow(AlertService).to receive(:trigger).and_raise(StandardError, "Slack API down")
    end

    it "raises so the job marks event as failed" do
      expect { call }.to raise_error(StandardError, "Slack API down")
    end
  end
end
