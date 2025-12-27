# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'site_admin/onboarding/welcome.html.erb', type: :view do
  let(:website) { create(:pwb_website, subdomain: 'test-onboarding') }
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

  before do
    assign(:steps, steps)
    assign(:step, 1)
    assign(:current_step_info, steps[1])

    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_website).and_return(website)
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  it 'renders welcome heading' do
    render

    expect(rendered).to match(/welcome/i)
  end

  it 'has continue button' do
    render

    expect(rendered).to have_selector('input[type="submit"], button[type="submit"], a.btn', minimum: 1)
  end

  it 'displays step progress' do
    render partial: 'site_admin/onboarding/progress', locals: {
      steps: steps,
      current_step: 1,
      total_steps: 5
    }

    expect(rendered).to include('Welcome')
  end
end
