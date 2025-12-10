# frozen_string_literal: true

# Background job to clean up orphaned ActiveStorage blobs
#
# Orphaned blobs can occur when:
# - Parent records are deleted without proper cleanup
# - Direct uploads fail before attachment
# - Database transactions roll back after blob creation
#
# This job runs daily via Solid Queue recurring tasks and purges
# blobs that have been unattached for more than 24 hours.
#
# Usage:
#   CleanupOrphanedBlobsJob.perform_later
#   CleanupOrphanedBlobsJob.perform_later(grace_period: 48.hours)
#
class CleanupOrphanedBlobsJob < ApplicationJob
  queue_as :low

  # Don't retry - if it fails, it'll run again tomorrow
  discard_on StandardError do |job, error|
    Rails.logger.error "[CleanupOrphanedBlobsJob] Failed: #{error.message}"
  end

  def perform(grace_period: 24.hours)
    Rails.logger.info "[CleanupOrphanedBlobsJob] Starting orphaned blob cleanup"

    orphaned_blobs = find_orphaned_blobs(grace_period)
    count = orphaned_blobs.count

    if count.zero?
      Rails.logger.info "[CleanupOrphanedBlobsJob] No orphaned blobs found"
      return { purged: 0, errors: 0 }
    end

    Rails.logger.info "[CleanupOrphanedBlobsJob] Found #{count} orphaned blobs to purge"

    purged = 0
    errors = 0

    orphaned_blobs.find_each do |blob|
      begin
        blob.purge
        purged += 1
        Rails.logger.info "[CleanupOrphanedBlobsJob] Purged blob #{blob.id}: #{blob.key}"
      rescue => e
        errors += 1
        Rails.logger.error "[CleanupOrphanedBlobsJob] Failed to purge blob #{blob.id}: #{e.message}"
      end
    end

    Rails.logger.info "[CleanupOrphanedBlobsJob] Completed: #{purged} purged, #{errors} errors"
    { purged: purged, errors: errors }
  end

  private

  def find_orphaned_blobs(grace_period)
    # Find blobs that:
    # 1. Have no attachments (orphaned)
    # 2. Were created more than grace_period ago (avoid purging in-progress uploads)
    ActiveStorage::Blob
      .left_joins(:attachments)
      .where(active_storage_attachments: { id: nil })
      .where('active_storage_blobs.created_at < ?', grace_period.ago)
  end
end
