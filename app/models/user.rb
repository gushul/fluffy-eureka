class User < ApplicationRecord
  has_one :account, dependent: :destroy
  has_many :orders, dependent: :destroy
end
