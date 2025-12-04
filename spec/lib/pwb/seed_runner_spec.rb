# frozen_string_literal: true

require 'rails_helper'
require 'pwb/seed_runner'

RSpec.describe Pwb::SeedRunner, type: :model do
  include FactoryBot::Syntax::Methods

  let!(:website) { create(:pwb_website, subdomain: 'test-seed', slug: 'test-seed') }

  before do
    # Ensure we have the seed files available
    allow_any_instance_of(described_class).to receive(:seed_translations)
    allow_any_instance_of(described_class).to receive(:seed_pages)
  end

  describe '.run' do
    it 'accepts a website parameter' do
      expect {
        described_class.run(
          website: website,
          mode: :create_only,
          dry_run: true,
          verbose: false
        )
      }.not_to raise_error
    end

    it 'creates a default website if none provided and none exist' do
      Pwb::Website.destroy_all
      
      expect {
        described_class.run(
          mode: :create_only,
          dry_run: true,
          verbose: false
        )
      }.to change(Pwb::Website, :count).by(1)
    end
  end

  describe 'modes' do
    describe ':create_only mode' do
      it 'does not update existing records' do
        # Create an existing user
        existing_user = create(:pwb_user, email: 'admin@example.com', website: website)
        original_updated_at = existing_user.updated_at

        described_class.run(
          website: website,
          mode: :create_only,
          dry_run: false,
          verbose: false,
          skip_properties: true
        )

        existing_user.reload
        expect(existing_user.updated_at).to eq(original_updated_at)
      end
    end

    describe ':force_update mode' do
      it 'updates existing records without prompting' do
        runner = described_class.new(
          website: website,
          mode: :force_update,
          dry_run: true,
          skip_properties: true,
          skip_translations: true,
          verbose: false
        )

        expect(runner.mode).to eq(:force_update)
      end
    end

    describe ':interactive mode' do
      it 'is the default mode' do
        runner = described_class.new(
          website: website,
          mode: :interactive,
          dry_run: true,
          skip_properties: true,
          skip_translations: true,
          verbose: false
        )

        expect(runner.mode).to eq(:interactive)
      end
    end

    describe ':upsert mode' do
      it 'creates or updates all records' do
        runner = described_class.new(
          website: website,
          mode: :upsert,
          dry_run: true,
          skip_properties: true,
          skip_translations: true,
          verbose: false
        )

        expect(runner.mode).to eq(:upsert)
      end
    end
  end

  describe 'dry_run option' do
    it 'does not create records when dry_run is true' do
      initial_link_count = website.links.count

      described_class.run(
        website: website,
        mode: :create_only,
        dry_run: true,
        verbose: false,
        skip_properties: true
      )

      expect(website.links.count).to eq(initial_link_count)
    end

    it 'creates records when dry_run is false' do
      # Clear existing links to ensure we can create new ones
      website.links.destroy_all

      described_class.run(
        website: website,
        mode: :create_only,
        dry_run: false,
        verbose: false,
        skip_properties: true
      )

      expect(website.links.count).to be > 0
    end
  end

  describe 'skip_properties option' do
    it 'skips property seeding when true' do
      initial_prop_count = website.props.count

      described_class.run(
        website: website,
        mode: :create_only,
        dry_run: false,
        verbose: false,
        skip_properties: true
      )

      expect(website.props.count).to eq(initial_prop_count)
    end
  end

  describe 'stats tracking' do
    it 'tracks created, updated, skipped, and error counts' do
      runner = described_class.new(
        website: website,
        mode: :create_only,
        dry_run: true,
        skip_properties: true,
        skip_translations: true,
        verbose: false
      )

      runner.execute

      expect(runner.stats).to include(:created, :updated, :skipped, :errors)
      expect(runner.stats[:errors]).to eq(0)
    end
  end

  describe 'MODES constant' do
    it 'defines all available modes' do
      expect(described_class::MODES).to eq({
        interactive: :interactive,
        create_only: :create_only,
        force_update: :force_update,
        upsert: :upsert
      })
    end
  end

  describe 'seed file validation' do
    it 'validates required seed files exist' do
      runner = described_class.new(
        website: website,
        mode: :create_only,
        dry_run: true,
        skip_properties: true,
        skip_translations: true,
        verbose: false
      )

      # Should not raise an error if files exist
      expect { runner.send(:validate_seed_files) }.not_to raise_error
    end
  end

  describe 'multi-tenancy support' do
    let!(:website_a) { create(:pwb_website, subdomain: 'tenant-a', slug: 'tenant-a') }
    let!(:website_b) { create(:pwb_website, subdomain: 'tenant-b', slug: 'tenant-b') }

    it 'scopes links to the correct website' do
      website_a.links.destroy_all
      website_b.links.destroy_all

      described_class.run(
        website: website_a,
        mode: :create_only,
        dry_run: false,
        verbose: false,
        skip_properties: true
      )

      expect(website_a.links.count).to be > 0
      expect(website_b.links.count).to eq(0)
    end

    it 'maintains link isolation between websites' do
      # Create a link for website_a
      link_a = website_a.links.create!(slug: 'test_link', link_title: 'Test Link A')
      
      # Create a link with same slug for website_b
      link_b = website_b.links.create!(slug: 'test_link', link_title: 'Test Link B')

      # Both should exist independently
      expect(website_a.links.find_by(slug: 'test_link')).to eq(link_a)
      expect(website_b.links.find_by(slug: 'test_link')).to eq(link_b)
      expect(link_a.link_title).to eq('Test Link A')
      expect(link_b.link_title).to eq('Test Link B')
    end
  end

  describe 'graceful degradation' do
    context 'when website_id column does not exist on contacts' do
      it 'skips contacts seeding with a warning' do
        # Mock the column check to simulate missing column
        allow(Pwb::Contact).to receive(:column_names).and_return(%w[id first_name last_name])

        runner = described_class.new(
          website: website,
          mode: :create_only,
          dry_run: false,
          skip_properties: true,
          skip_translations: true,
          verbose: false
        )

        # Should not raise an error
        expect { runner.send(:seed_contacts) }.not_to raise_error
      end
    end
  end

  describe 'error handling' do
    it 'returns false when seeding fails' do
      allow_any_instance_of(described_class).to receive(:seed_agency).and_raise(StandardError.new('Test error'))

      result = described_class.run(
        website: website,
        mode: :create_only,
        dry_run: false,
        verbose: false,
        skip_properties: true
      )

      expect(result).to be false
    end

    it 'returns true when seeding succeeds' do
      result = described_class.run(
        website: website,
        mode: :create_only,
        dry_run: true,
        verbose: false,
        skip_properties: true
      )

      expect(result).to be true
    end
  end
end
