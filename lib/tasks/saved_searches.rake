# frozen_string_literal: true

namespace :saved_searches do
  desc "Run daily search alerts - schedule to run once per day (e.g., 8am)"
  task run_daily: :environment do
    puts "[#{Time.current}] Running daily search alerts..."

    searches = Pwb::SavedSearch.daily_alerts.where(
      "last_run_at IS NULL OR last_run_at < ?", 23.hours.ago
    )

    count = searches.count
    puts "Found #{count} daily searches to process"

    searches.find_each do |search|
      puts "  - Queueing search #{search.id} (#{search.email})"
      Pwb::SearchAlertJob.perform_later(search.id)
    end

    puts "[#{Time.current}] Queued #{count} daily search alerts"
  end

  desc "Run weekly search alerts - schedule to run once per week (e.g., Monday 8am)"
  task run_weekly: :environment do
    puts "[#{Time.current}] Running weekly search alerts..."

    searches = Pwb::SavedSearch.weekly_alerts.where(
      "last_run_at IS NULL OR last_run_at < ?", 6.days.ago
    )

    count = searches.count
    puts "Found #{count} weekly searches to process"

    searches.find_each do |search|
      puts "  - Queueing search #{search.id} (#{search.email})"
      Pwb::SearchAlertJob.perform_later(search.id)
    end

    puts "[#{Time.current}] Queued #{count} weekly search alerts"
  end

  desc "Run all pending alerts (daily and weekly) - useful for testing"
  task run_all: :environment do
    Rake::Task["saved_searches:run_daily"].invoke
    Rake::Task["saved_searches:run_weekly"].invoke
  end

  desc "Show statistics about saved searches"
  task stats: :environment do
    puts "\n=== Saved Search Statistics ==="
    puts ""

    total = Pwb::SavedSearch.count
    enabled = Pwb::SavedSearch.enabled.count
    daily = Pwb::SavedSearch.daily_alerts.count
    weekly = Pwb::SavedSearch.weekly_alerts.count
    verified = Pwb::SavedSearch.verified.count

    puts "Total saved searches: #{total}"
    puts "  - Enabled: #{enabled}"
    puts "  - Daily alerts: #{daily}"
    puts "  - Weekly alerts: #{weekly}"
    puts "  - Email verified: #{verified}"
    puts ""

    alerts_today = Pwb::SearchAlert.where("created_at > ?", 24.hours.ago).count
    alerts_sent = Pwb::SearchAlert.where("sent_at > ?", 24.hours.ago).count

    puts "Alerts (last 24 hours):"
    puts "  - Created: #{alerts_today}"
    puts "  - Sent: #{alerts_sent}"
    puts ""

    # Group by website
    puts "By website:"
    Pwb::SavedSearch.group(:website_id).count.each do |website_id, count|
      website = Pwb::Website.find_by(id: website_id)
      puts "  - #{website&.subdomain || 'Unknown'}: #{count} searches"
    end
    puts ""
  end

  desc "Clean up old search alerts (older than 90 days)"
  task cleanup: :environment do
    puts "[#{Time.current}] Cleaning up old search alerts..."

    cutoff = 90.days.ago
    old_alerts = Pwb::SearchAlert.where("created_at < ?", cutoff)
    count = old_alerts.count

    if count > 0
      old_alerts.delete_all
      puts "Deleted #{count} search alerts older than #{cutoff.to_date}"
    else
      puts "No old alerts to clean up"
    end
  end

  desc "Clean up unverified searches older than 7 days"
  task cleanup_unverified: :environment do
    puts "[#{Time.current}] Cleaning up unverified searches..."

    cutoff = 7.days.ago
    unverified = Pwb::SavedSearch.where(email_verified: false).where("created_at < ?", cutoff)
    count = unverified.count

    if count > 0
      unverified.destroy_all
      puts "Deleted #{count} unverified searches older than #{cutoff.to_date}"
    else
      puts "No unverified searches to clean up"
    end
  end
end
