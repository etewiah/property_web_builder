# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe DemoProvisioner do
    include ActiveSupport::Testing::TimeHelpers

    let!(:tenant_settings) do
      Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |settings|
        settings.default_available_themes = %w[default brisbane bologna barcelona biarritz]
      end
    end

    let(:seed_pack_double) { instance_double(Pwb::SeedPack, apply!: true) }

    before do
      allow(Pwb::SeedPack).to receive(:find).and_return(seed_pack_double)
      allow(ActiveRecord::Base).to receive(:connected_to).and_yield
      allow(PwbTenant::ApplicationRecord).to receive(:connected_to).and_yield
    end

    describe '.provision' do
      it 'creates a new demo website on the demo shard' do
        travel_to Time.zone.parse('2026-01-07 09:00:00 UTC') do
          described_class.provision(subdomain: 'demo-alpha', seed_pack: 'spain_luxury', shard: :demo)
        end

        website = Pwb::Website.find_by(subdomain: 'demo-alpha')
        expect(website).to be_present
        expect(website.demo_mode).to be(true)
        expect(website.shard_name).to eq('demo')
        expect(website.demo_seed_pack).to eq('spain_luxury')
        expect(website.demo_last_reset_at).to be_within(1.second).of(Time.zone.parse('2026-01-07 09:00:00 UTC'))
        expect(Pwb::Current.website).to be_nil
      end

      it 'reuses an existing website and reapplies the seed pack' do
        existing = FactoryBot.create(
          :pwb_website,
          subdomain: 'demo-beta',
          demo_mode: true,
          demo_seed_pack: 'spain_luxury',
          shard_name: 'demo'
        )
        existing.update!(demo_last_reset_at: 3.days.ago)

        expect do
          described_class.provision(subdomain: 'demo-beta', seed_pack: 'spain_luxury', shard: :demo)
        end.not_to change(Pwb::Website, :count)

        expect(seed_pack_double).to have_received(:apply!).with(website: existing, options: { verbose: true })
        expect(existing.reload.demo_last_reset_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
