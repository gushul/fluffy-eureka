# == Schema Information
#
# Table name: idempotency_keys
#
#  key        :string           not null, primary key
#  response   :jsonb            not null
#  created_at :timestamptz      not null
#
class IdempotencyKey < ApplicationRecord
  self.primary_key = :key

  validates :key, :response, presence: true
end
