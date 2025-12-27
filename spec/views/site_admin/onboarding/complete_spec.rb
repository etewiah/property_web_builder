# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'site_admin/onboarding/complete.html.erb', type: :view do
  let(:website) { create(:pwb_website, subdomain: 'test-onboarding', theme_name: 'default') }
  let(:user) { create(:pwb_user, email: 'owner@example.com', website: website) }

  let(:steps) do
    {
      1 => { name: 'welcome', title: 'Welcome', description: 'Get started' },
      2 => { name: 'profile', title: 'Profile', description: 'Set up profile' },
      3 => { name: 'property', title: 'Property', description: 'Add property' },
      4 => { name: 'theme', title: 'Theme', description: 'Choose theme' },
      5 => { name: 'complete', title: 'Complete', description: 'All done' }
    }
  end

  let(:stats) do
    {
      properties: 1,
      pages: 5,
      theme: 'Default'
    }
  end

  before do
    assign(:steps, steps)
    assign(:step, 5)
    assign(:website, website)
    assign(:stats, stats)

    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_website).and_return(website)
    allow(Pwb::Current).to receive(:website).and_return(website)

    # Stub route helpers used in the view
    allow(view).to receive(:site_admin_dashboard_path).and_return('/site_admin')
    allow(view).to receive(:site_admin_root_path).and_return('/site_admin')
    allow(view).to receive(:root_path).and_return('/')
  end

  it 'displays completion message' do
    render

    expect(rendered).to match(/complete|done|ready|congratulations/i)
  end

  it 'shows property count' do
    render

    expect(rendered).to include('1')
  end

  it 'shows theme name' do
    render

    expect(rendered).to include('Default')
  end

  it 'has link to dashboard' do
    render

    expect(rendered).to have_selector('a[href*="site_admin"]')
  end

  it 'has link to view website' do
    render

    # Should have a link to view the live site
    expect(rendered).to have_selector('a[target="_blank"]') |
      have_link(text: /view|website/i)
  end
end
