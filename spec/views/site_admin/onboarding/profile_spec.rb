# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'site_admin/onboarding/profile.html.erb', type: :view do
  let(:website) { create(:pwb_website, subdomain: 'test-onboarding') }
  let(:user) { create(:pwb_user, email: 'owner@example.com', website: website) }
  let(:agency) { Pwb::Agency.new }

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
    assign(:step, 2)
    assign(:current_step_info, steps[2])
    assign(:agency, agency)

    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_website).and_return(website)
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  it 'renders profile form' do
    render

    expect(rendered).to have_selector('form')
  end

  it 'has agency display name field' do
    render

    expect(rendered).to have_selector('input[name*="display_name"]')
  end

  it 'has email field' do
    render

    expect(rendered).to have_selector('input[name*="email"]')
  end

  it 'has phone field' do
    render

    expect(rendered).to have_selector('input[name*="phone"]')
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
