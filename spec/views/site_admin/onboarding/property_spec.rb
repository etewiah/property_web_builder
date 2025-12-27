# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'site_admin/onboarding/property.html.erb', type: :view do
  let(:website) { create(:pwb_website, subdomain: 'test-onboarding') }
  let(:user) { create(:pwb_user, email: 'owner@example.com', website: website) }
  let(:property) { Pwb::RealtyAsset.new }
  let(:property_types) { [] }

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
    assign(:step, 3)
    assign(:current_step_info, steps[3])
    assign(:property, property)
    assign(:property_types, property_types)

    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_website).and_return(website)
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  it 'renders property form' do
    render

    expect(rendered).to have_selector('form')
  end

  it 'has property title field' do
    render

    expect(rendered).to have_selector('input[name*="title"]')
  end

  it 'has bedroom count field' do
    render

    expect(rendered).to have_selector('input[name*="bedroom"]')
  end

  it 'has bathroom count field' do
    render

    expect(rendered).to have_selector('input[name*="bathroom"]')
  end

  it 'has city field' do
    render

    expect(rendered).to have_selector('input[name*="city"]')
  end

  it 'has description field' do
    render

    expect(rendered).to have_selector('textarea[name*="description"]')
  end

  it 'has listing type checkboxes' do
    render

    expect(rendered).to have_selector('input[name*="for_sale"]')
    expect(rendered).to have_selector('input[name*="for_rent"]')
  end

  it 'has submit button' do
    render

    expect(rendered).to have_selector('input[type="submit"], button[type="submit"]')
  end

  it 'has skip link' do
    render

    expect(rendered).to match(/skip/i)
  end

  it 'has back link' do
    render

    expect(rendered).to have_link('Back')
  end
end
