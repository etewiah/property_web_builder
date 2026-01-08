# frozen_string_literal: true

module Pwb
  # Audit log for shard assignment operations
  #
  # Tracks all changes to website shard assignments for security and debugging.
  # Each log entry records who changed what, when, and why.
  #
  # @example
  #   log = Pwb::ShardAuditLog.create!(
  #     website: website,
  #     old_shard_name: 'default',
  #     new_shard_name: 'shard_1',
  #     changed_by_email: 'admin@example.com',
  #     notes: 'Moving to dedicated shard for performance'
  #   )
  class ShardAuditLog < ApplicationRecord
    self.table_name = 'pwb_shard_audit_logs'
    
    # Associations
    belongs_to :website, class_name: 'Pwb::Website'
    
    # Validations
    validates :new_shard_name, presence: true
    validates :changed_by_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :status, presence: true, inclusion: { in: %w[pending in_progress completed failed rolled_back] }
    
    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :for_website, ->(website_id) { where(website_id: website_id) }
    scope :by_user, ->(email) { where(changed_by_email: email) }
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    scope :in_progress, -> { where(status: %w[pending in_progress]) }
    
    # Class methods
    
    # Check if a migration is currently in progress for a website
    # @param website [Pwb::Website]
    # @return [Boolean]
    def self.migration_in_progress?(website)
      where(website: website, status: %w[pending in_progress]).exists?
    end
    
    # Get the most recent log entry for a website
    # @param website [Pwb::Website]
    # @return [Pwb::ShardAuditLog, nil]
    def self.latest_for_website(website)
      for_website(website.id).recent.first
    end
    
    # Instance methods
    
    # Human-readable status
    # @return [String]
    def status_label
      status.titleize
    end
    
    # Was this a successful operation?
    # @return [Boolean]
    def successful?
      status == 'completed'
    end
    
    # Did this operation fail?
    # @return [Boolean]
    def failed?
      status == 'failed'
    end
    
    # Is this operation still in progress?
    # @return [Boolean]
    def in_progress?
      %w[pending in_progress].include?(status)
    end
    
    # Duration of the operation (if completed)
    # @return [ActiveSupport::Duration, nil]
    def duration
      return nil unless completed_at = updated_at
      return nil if created_at.nil?
      
      completed_at - created_at
    end
    
    # Format duration as human-readable string
    # @return [String, nil]
    def duration_humanized
      return nil unless duration
      
      seconds = duration.to_i
      if seconds < 60
        "#{seconds}s"
      elsif seconds < 3600
        "#{seconds / 60}m #{seconds % 60}s"
      else
        "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
      end
    end
  end
end
