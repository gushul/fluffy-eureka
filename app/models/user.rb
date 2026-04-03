class User < ApplicationRecord
  has_one  :account, dependent: :destroy
  has_many :orders, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  after_create :create_default_account

  private

  def create_default_account
    create_account!(balance_cents: 0)
  end
end
