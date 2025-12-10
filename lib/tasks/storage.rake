# frozen_string_literal: true

namespace :storage do
  desc "Show ActiveStorage statistics including orphaned blobs"
  task stats: :environment do
    total_blobs = ActiveStorage::Blob.count
    total_attachments = ActiveStorage::Attachment.count

    orphaned_blobs = ActiveStorage::Blob
      .left_joins(:attachments)
      .where(active_storage_attachments: { id: nil })

    orphan_count = orphaned_blobs.count
    orphan_size = orphaned_blobs.sum(:byte_size)

    recent_orphans = orphaned_blobs.where('active_storage_blobs.created_at > ?', 24.hours.ago).count
    old_orphans = orphaned_blobs.where('active_storage_blobs.created_at < ?', 24.hours.ago).count

    puts "\n=== ActiveStorage Statistics ==="
    puts "Total blobs:        #{total_blobs}"
    puts "Total attachments:  #{total_attachments}"
    puts ""
    puts "=== Orphaned Blobs ==="
    puts "Total orphaned:     #{orphan_count}"
    puts "  - Recent (<24h):  #{recent_orphans} (will be kept)"
    puts "  - Old (>24h):     #{old_orphans} (eligible for cleanup)"
    puts "Orphan size:        #{number_to_human_size(orphan_size)}"
    puts ""

    if orphan_count > 0
      puts "Run 'rails storage:cleanup' to purge old orphaned blobs"
    else
      puts "No orphaned blobs found!"
    end
    puts ""
  end

  desc "Purge orphaned blobs older than 24 hours"
  task cleanup: :environment do
    puts "Starting orphaned blob cleanup..."
    result = CleanupOrphanedBlobsJob.perform_now
    puts "Completed: #{result[:purged]} purged, #{result[:errors]} errors"
  end

  desc "Purge ALL orphaned blobs (including recent ones - use with caution)"
  task cleanup_all: :environment do
    print "This will purge ALL orphaned blobs including recent uploads. Continue? [y/N] "
    response = $stdin.gets.chomp
    unless response.downcase == 'y'
      puts "Aborted."
      exit
    end

    puts "Starting full orphaned blob cleanup..."
    result = CleanupOrphanedBlobsJob.perform_now(grace_period: 0.seconds)
    puts "Completed: #{result[:purged]} purged, #{result[:errors]} errors"
  end

  private

  def number_to_human_size(bytes)
    return "0 Bytes" if bytes.nil? || bytes == 0

    units = %w[Bytes KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp > units.length - 1

    "%.2f %s" % [bytes.to_f / 1024**exp, units[exp]]
  end
end
