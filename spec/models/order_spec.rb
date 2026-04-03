require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'creation' do
    let(:user) { create(:user) }

    it 'sets status to created by default' do
      order = described_class.new(user: user, amount: 10.0)
      expect(order.status).to eq('created')
    end
  end
end
