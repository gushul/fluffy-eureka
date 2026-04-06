# == Schema Information
#
# Table name: outbox_events
#
#  id           :bigint           not null, primary key
#  attempts     :integer          default(0), not null
#  error        :text
#  event_type   :string           not null
#  payload      :jsonb            not null
#  processed_at :datetime
#  created_at   :datetime         not null
#
# Indexes
#
#  index_outbox_events_on_created_at  (created_at)
#  index_outbox_events_on_event_type  (event_type)
#  index_outbox_unprocessed           (id) WHERE (processed_at IS NULL)
#
class OutboxEvent < ApplicationRecord
  MAX_ATTEMPTS = 3

  validates :event_type, :payload, presence: true

  scope :processable, -> { where(processed_at: nil).where("attempts < ?", MAX_ATTEMPTS) }
end
