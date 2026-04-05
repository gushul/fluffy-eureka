# == Schema Information
#
# Table name: audit_logs
#
#  id          :bigint           not null
#  action      :string           not null
#  actor_type  :string           not null
#  changes     :jsonb
#  entity_type :string           not null
#  ip_address  :inet
#  user_agent  :text
#  created_at  :timestamptz      not null
#  actor_id    :bigint
#  entity_id   :bigint           not null
#  user_id     :bigint
#
class AuditLog < ApplicationRecord
  validates :action, presence: true
  validates :actor_type, presence: true

  belongs_to :user, optional: true
  belongs_to :entity, polymorphic: true

  def readonly?
    persisted?
  end

  before_destroy do
    raise ActiveRecord::ReadOnlyRecord
  end
end
