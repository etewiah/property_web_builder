# frozen_string_literal: true

module Pwb
  class DemoProvisioner
    def self.provision(subdomain:, seed_pack:, shard: :demo)
      new(subdomain, seed_pack, shard).provision
    end

    def initialize(subdomain, seed_pack, shard)
      @subdomain = subdomain
      @seed_pack = seed_pack
      @shard = shard.to_sym
    end

    def provision
      website = find_or_create_website

      ActsAsTenant.with_tenant(website) do
        Pwb::Current.website = website
        PwbTenant::ApplicationRecord.connected_to(shard: @shard, role: :writing) do
          ActiveRecord::Base.connected_to(role: :writing, shard: @shard) do
            apply_seed_pack(website)
          end
        end
      end

      website.update!(demo_last_reset_at: Time.current)
      website
    ensure
      Pwb::Current.reset
      ActsAsTenant.current_tenant = nil
    end

    private

    def find_or_create_website
      Website.find_or_create_by!(subdomain: @subdomain) do |website|
        website.shard_name = @shard.to_s
        website.demo_mode = true
        website.demo_seed_pack = @seed_pack
        website.provisioning_state = 'live'
        website.site_type = 'residential'
      end
    end

    def apply_seed_pack(website)
      return if @seed_pack.blank?

      pack = SeedPack.find(@seed_pack)
      pack.apply!(website: website, options: { verbose: true })
    end
  end
end
