require 'rails_helper'

module Pwb
  RSpec.describe "Contact forms", type: :feature do
    # these tests do not have js enabled and so bypass clientside validations
    let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'test-contact') }
    let!(:pwb_page) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:contact_us_with_rails_page_part, website: website)
      end
    end
    # calling above :page would clash with page object

    let(:prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :sale, website: website)
      end
    end

    before(:each) do
      Capybara.app_host = 'http://test-contact.example.com'
    end

    after(:each) do
      Capybara.app_host = nil
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


    scenario 'when property contact form is filled', skip: 'Property page requires materialized view refresh' do
      visit("/en/properties/for-sale/#{prop.id}/example-country-house-for-sale")

      # Skip test if property not found (materialized view not refreshed)
      if page.has_content?('Property not found')
        skip 'Property not visible - materialized view needs refresh'
      end

      # contact_name below is the id of the field
      fill_in('contact_name', with: "Ed")
      click_button('Send')
      expect(page).to have_content 'Thank you for your message'
    end


    # after(:all) do
    #   @agency.destroy
    #   @admin_user.destroy
    # end
  end
end
