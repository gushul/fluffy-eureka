module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }

    scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :with_deleted,  -> { unscoped }
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def soft_deleted?
    deleted_at.present?
  end

  def restore!
    update!(deleted_at: nil)
  end
end
