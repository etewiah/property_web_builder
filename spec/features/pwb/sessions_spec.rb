require 'rails_helper'

module Pwb
  RSpec.describe "Sessions", type: :feature do
    let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'test-sessions') }
    let!(:agency) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_agency, company_name: 'my re', website: website)
      end
    end
    let!(:admin_user) { User.create!(email: "user@example.org", password: "very-secret", admin: true, website: website) }

    before(:each) do
      Pwb::Current.reset
      Capybara.app_host = 'http://test-sessions.example.com'
    end

    after(:each) do
      Capybara.app_host = nil
    end

    scenario 'with valid credentials' do
      visit('/users/sign_in')
      fill_in('Email', with: admin_user.email)
      fill_in('Password', with: 'very-secret')
      click_button('Sign in')
      # Admin path changed from /admin to /site_admin
      expect(current_path).to include("/site_admin").or include("/admin")
    end

    scenario 'with invalid password' do
      visit('/users/sign_in')
      fill_in('Email', with: admin_user.email)
      fill_in('Password', with: 'bananas')
      click_button('Sign in')
      expect(page).to have_content 'Invalid email or password'
    end
  end
end
