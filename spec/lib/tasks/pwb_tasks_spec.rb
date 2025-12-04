# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'pwb:db rake tasks' do
  before(:all) do
    Rake.application.rake_require 'tasks/pwb_tasks'
    Rake::Task.define_task(:environment)
  end

  describe 'pwb:db:validate_seeds' do
    let(:task) { Rake::Task['pwb:db:validate_seeds'] }

    before do
      task.reenable
    end

    it 'runs without errors when seed files exist' do
      expect { task.invoke }.not_to raise_error
    end
  end

  describe 'pwb:db:seed_dry_run' do
    let(:task) { Rake::Task['pwb:db:seed_dry_run'] }

    before do
      task.reenable
      # Ensure a website exists with a non-reserved subdomain
      Pwb::Website.first_or_create!(
        subdomain: 'rake-test-site',
        theme_name: 'bristol',
        default_currency: 'EUR',
        default_client_locale: 'en-UK'
      )
    end

    it 'runs in dry-run mode without making changes' do
      initial_link_count = Pwb::Link.count
      
      expect { task.invoke }.to output(/DRY RUN MODE/).to_stdout
      
      expect(Pwb::Link.count).to eq(initial_link_count)
    end
  end

  describe 'seed mode parsing' do
    it 'parses create_only mode' do
      expect(parse_seed_mode('create_only')).to eq(:create_only)
      expect(parse_seed_mode('create')).to eq(:create_only)
    end

    it 'parses force_update mode' do
      expect(parse_seed_mode('force_update')).to eq(:force_update)
      expect(parse_seed_mode('update')).to eq(:force_update)
      expect(parse_seed_mode('force')).to eq(:force_update)
    end

    it 'parses upsert mode' do
      expect(parse_seed_mode('upsert')).to eq(:upsert)
    end

    it 'defaults to interactive mode' do
      expect(parse_seed_mode(nil)).to eq(:interactive)
      expect(parse_seed_mode('')).to eq(:interactive)
      expect(parse_seed_mode('unknown')).to eq(:interactive)
    end
  end
end
