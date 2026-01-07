# frozen_string_literal: true

module Pwb
  module DemoWebsite
    extend ActiveSupport::Concern

    included do
      scope :demos, -> { where(demo_mode: true) }
      scope :on_demo_shard, -> { where(shard_name: 'demo') }
    end

    def demo?
      demo_mode?
    end

    def demo_reset_interval_duration
      interval = demo_reset_interval

      case interval
      when ActiveSupport::Duration
        interval
      when Numeric
        interval.seconds
      when String
        parse_interval_string(interval)
      else
        24.hours
      end
    end

    def reset_demo_data!
      return unless demo?

      ActiveRecord::Base.connected_to(role: :writing, shard: database_shard) do
        PwbTenant::ApplicationRecord.connected_to(shard: database_shard, role: :writing) do
          ActsAsTenant.with_tenant(self) do
            Pwb::Current.website = self
            transaction do
              clear_tenant_data!
              apply_demo_seed_pack!
              update!(demo_last_reset_at: Time.current)
            end
          end
        end
      end
    ensure
      Pwb::Current.reset
      ActsAsTenant.current_tenant = nil
    end

    private

    def apply_demo_seed_pack!
      return if demo_seed_pack.blank?

      Pwb::SeedPack.find(demo_seed_pack).apply!(website: self, options: { verbose: false })
    rescue StandardError => e
      Rails.logger.error("[DemoWebsite] Failed to apply seed pack #{demo_seed_pack}: #{e.message}")
      raise
    end

    def clear_tenant_data!
      [
        realty_assets,
        contacts,
        messages,
        support_tickets,
        ticket_messages,
        media,
        media_folders,
        widget_configs
      ].each do |relation|
        relation.destroy_all
      end
    end

    def parse_interval_string(value)
      normalized = value.to_s.strip.downcase
      return 24.hours if normalized.blank?

      number = normalized[/\d+/].to_i
      number = 24 if number.zero?

      if normalized.include?('day')
        number.days
      elsif normalized.include?('hour')
        number.hours
      elsif normalized.include?('minute')
        number.minutes
      else
        number.seconds
      end
    end
  end
end
