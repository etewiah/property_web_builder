# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'site_admin/onboarding/theme.html.erb', type: :view do
  let(:website) { create(:pwb_website, subdomain: 'test-onboarding') }
  let(:user) { create(:pwb_user, email: 'owner@example.com', website: website) }
  let(:themes) { ['default', 'brisbane', 'bologna'] }

  let(:steps) do
    {
      1 => { name: 'welcome', title: 'Welcome', description: 'Get started' },
      2 => { name: 'profile', title: 'Profile', description: 'Set up profile' },
      3 => { name: 'property', title: 'Property', description: 'Add property' },
      4 => { name: 'theme', title: 'Theme', description: 'Choose theme' },
      5 => { name: 'complete', title: 'Complete', description: 'All done' }
    }
  end

  before do
    assign(:steps, steps)
    assign(:step, 4)
    assign(:current_step_info, steps[4])
    assign(:themes, themes)
    assign(:current_theme, 'default')

    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_website).and_return(website)
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  it 'renders theme selection form' do
    render

    expect(rendered).to have_selector('form')
  end

  it 'displays available themes' do
    render

    themes.each do |theme|
      expect(rendered).to include(theme)
    end
  end

  it 'has theme selection inputs' do
    render

    expect(rendered).to have_selector('input[name*="theme"]', minimum: 1)
  end

  it 'has submit button' do
    render

    expect(rendered).to have_selector('input[type="submit"], button[type="submit"]')
  end

  it 'has back link' do
    render

    expect(rendered).to have_link('Back')
  end
end
