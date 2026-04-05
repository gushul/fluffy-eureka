# == Schema Information
#
# Table name: domain_events
#
#  id           :bigint           not null, primary key
#  attempts     :integer          default(0), not null
#  event_type   :string           not null
#  last_error   :text
#  payload      :jsonb            not null
#  processed_at :datetime
#  source_type  :string           not null
#  status       :string           default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  source_id    :bigint           not null
#
# Indexes
#
#  index_domain_events_on_event_type                 (event_type)
#  index_domain_events_on_source_type_and_source_id  (source_type,source_id)
#  index_domain_events_on_status_and_created_at      (status,created_at)
#
class DomainEvent < ApplicationRecord
  belongs_to :source, polymorphic: true

  # TODO: move to value object
  STATUSES = [
    PENDING = 'pending',
    DONE = 'done',
    FAILED = "failed"
  ].freeze

  def self.publish(event_type, source:, payload: {})
    create!(
      event_type:  event_type,
      source:      source,
      payload:     payload,
      status:      PENDING
    )
  end
end

