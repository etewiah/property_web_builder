# frozen_string_literal: true

class DemoResetJob < ApplicationJob
  queue_as :low

  def perform
    Pwb::Website.demos.on_demo_shard.find_each do |website|
      next unless should_reset?(website)

      website.reset_demo_data!
      Rails.logger.info("[DemoReset] Reset #{website.subdomain}")
    end
  end

  private

  def should_reset?(website)
    last_reset = website.demo_last_reset_at
    return true if last_reset.nil?

    interval = website.demo_reset_interval_duration
    last_reset < interval.ago
  end
end
