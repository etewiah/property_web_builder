# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'spp:provision rake task' do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('spp:provision')
  end

  let!(:website) { create(:pwb_website, subdomain: 'test-spp-tenant') }

  after do
    # Clean up to allow re-invocation
    Rake::Task['spp:provision'].reenable
  end

  it 'creates an SPP integration for the given subdomain' do
    expect {
      Rake::Task['spp:provision'].invoke('test-spp-tenant')
    }.to change(Pwb::WebsiteIntegration, :count).by(1)

    integration = website.integrations.find_by(category: 'spp')
    expect(integration).to be_present
    expect(integration.provider).to eq('single_property_pages')
    expect(integration.credential('api_key')).to be_present
    expect(integration.credential('api_key').length).to eq(64) # hex(32) = 64 chars
    expect(integration).to be_enabled
  end

  it 'is idempotent — does not create duplicate on re-run' do
    Rake::Task['spp:provision'].invoke('test-spp-tenant')
    Rake::Task['spp:provision'].reenable

    expect {
      Rake::Task['spp:provision'].invoke('test-spp-tenant')
    }.not_to change(Pwb::WebsiteIntegration, :count)
  end

  it 'aborts for non-existent subdomain' do
    expect {
      Rake::Task['spp:provision'].invoke('nonexistent')
    }.to raise_error(SystemExit)
  end
end
