require 'rails_helper'

module Pwb
  RSpec.describe "Sessions", type: :feature do
    before(:all) do
      @agency = FactoryGirl.create(:pwb_agency, company_name: 'my re')
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    end

    scenario 'with valid credentials' do
      visit('/users/sign_in')
      fill_in('Email', with: @admin_user.email)
      fill_in('Password', with: @admin_user.password)
      click_button('Sign in')
      expect(current_path).to include("/admin")
    end

    scenario 'with invalid password' do
      visit('/users/sign_in')
      fill_in('Email', with: @admin_user.email)
      fill_in('Password', with: 'bananas')
      click_button('Sign in')
      expect(page).to have_content 'Invalid email or password'
    end


    after(:all) do
      @agency.destroy
      @admin_user.destroy
    end
  end
end
