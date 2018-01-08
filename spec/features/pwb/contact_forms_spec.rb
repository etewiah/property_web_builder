require 'rails_helper'

module Pwb
  RSpec.describe "Contact forms", type: :feature do
    # before(:all) do
    #   @agency = FactoryGirl.create(:pwb_agency, company_name: 'my re')
    #   @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    # end
    let!(:pwb_page) { FactoryGirl.create(:contact_us_with_rails_page_part)}
    # calling above :page would clash with page object


    scenario 'when general contact form is filled' do
      visit('/contact-us')

      # contact_name below is the id of the field
      fill_in('contact_name', with: "Ed")
      # fill_in('Password', with: @admin_user.password)
      click_button('Send')

      expect(page).to have_content 'Thank you for your message'
      # expect(current_path).to include("/contact-us")
    end
    
    scenario 'when general contact form is filled' do
      visit('/contact-us')

      # contact_name below is the id of the field
      fill_in('contact_name', with: "Ed")
      # fill_in('Password', with: @admin_user.password)
      click_button('Send')

      expect(page).to have_content 'Thank you for your message'
      # expect(current_path).to include("/contact-us")
    end

    # after(:all) do
    #   @agency.destroy
    #   @admin_user.destroy
    # end
  end
end
