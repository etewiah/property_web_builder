# frozen_string_literal: true

module SiteAdmin
  # StorageStatsController
  # Provides ActiveStorage statistics and orphan monitoring
  # Only accessible to tenant admins (via TenantAdminConstraint)
  class StorageStatsController < SiteAdminController
    def show
      @stats = storage_stats
    end

    def cleanup
      result = CleanupOrphanedBlobsJob.perform_later
      redirect_to site_admin_storage_stats_path,
                  notice: "Cleanup job queued. Check back in a few minutes."
    end

    private

    def storage_stats
      orphaned_blobs = ActiveStorage::Blob
        .left_joins(:attachments)
        .where(active_storage_attachments: { id: nil })

      {
        total_blobs: ActiveStorage::Blob.count,
        total_attachments: ActiveStorage::Attachment.count,
        total_size: ActiveStorage::Blob.sum(:byte_size),
        orphan_count: orphaned_blobs.count,
        orphan_size: orphaned_blobs.sum(:byte_size),
        recent_orphans: orphaned_blobs.where('active_storage_blobs.created_at > ?', 24.hours.ago).count,
        old_orphans: orphaned_blobs.where('active_storage_blobs.created_at < ?', 24.hours.ago).count
      }
    end
  end
end
