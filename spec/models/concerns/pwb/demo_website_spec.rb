# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe DemoWebsite, type: :model do
    include ActiveSupport::Testing::TimeHelpers

    let!(:tenant_settings) do
      Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |settings|
        settings.default_available_themes = %w[default brisbane bologna barcelona biarritz]
      end
    end

    let(:website) do
      FactoryBot.create(
        :pwb_website,
        demo_mode: true,
        demo_seed_pack: 'spain_luxury',
        shard_name: 'default'
      )
    end

    describe '.demos' do
      it 'returns only demo websites' do
        demo_site = website
        regular_site = FactoryBot.create(:pwb_website, demo_mode: false)

        expect(Pwb::Website.demos).to contain_exactly(demo_site)
        expect(Pwb::Website.demos).not_to include(regular_site)
      end
    end

    describe '.on_demo_shard' do
      it 'filters by shard_name = demo' do
        demo_site = FactoryBot.create(:pwb_website, demo_mode: true, shard_name: 'demo')
        FactoryBot.create(:pwb_website, demo_mode: true, shard_name: 'default')

        expect(Pwb::Website.on_demo_shard).to contain_exactly(demo_site)
      end
    end

    describe '#demo_reset_interval_duration' do
      it 'respects persisted ActiveSupport::Duration values' do
        website.update!(demo_reset_interval: 12.hours)
        website.reload
        expect(website.demo_reset_interval_duration).to eq(12.hours)
      end

      it 'falls back to 24 hours for blank values' do
        website.update!(demo_reset_interval: nil)
        expect(website.demo_reset_interval_duration).to eq(24.hours)
      end
    end

    describe '#reset_demo_data!' do
      it 'returns immediately when website is not a demo' do
        non_demo = FactoryBot.create(:pwb_website, demo_mode: false)
        expect(Pwb::SeedPack).not_to receive(:find)
        non_demo.reset_demo_data!
      end

      it 'clears tenant data, reapplies the seed pack, and timestamps the reset' do
        seed_pack = instance_double(Pwb::SeedPack, apply!: true)
        allow(Pwb::SeedPack).to receive(:find).with('spain_luxury').and_return(seed_pack)
        allow(website).to receive(:clear_tenant_data!)

        travel_to Time.zone.parse('2026-01-07 12:00:00 UTC') do
          website.reset_demo_data!
          expect(website.reload.demo_last_reset_at).to eq(Time.current)
        end

        expect(website).to have_received(:clear_tenant_data!)
        expect(seed_pack).to have_received(:apply!).with(website: website, options: { verbose: false })
      end
    end
  end
end
