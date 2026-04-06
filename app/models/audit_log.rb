# == Schema Information
#
# Table name: audit_logs
#
#  id            :bigint           not null, primary key
#  action        :string           not null
#  actor_type    :string           not null
#  audit_changes :jsonb
#  entity_type   :string           not null
#  ip_address    :inet
#  user_agent    :text
#  created_at    :timestamptz      not null, primary key
#  actor_id      :bigint
#  entity_id     :bigint           not null
#  user_id       :bigint
#
class AuditLog < ApplicationRecord
  self.implicit_order_column = "created_at"

  validates :action, presence: true
  validates :actor_type, presence: true

  belongs_to :user, optional: true
  belongs_to :actor, polymorphic: true
  belongs_to :entity, polymorphic: true

  def auditable
    entity
  end

  def auditable=(val)
    self.entity = val
  end

  def readonly?
    persisted?
  end

  before_destroy do
    raise ActiveRecord::ReadOnlyRecord
  end
end
