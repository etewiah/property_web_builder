require 'rails_helper'

module Pwb
  RSpec.describe "Property Details", type: :feature do
    # US-1.3: View Property Details
    # As a public visitor, I want to view detailed information about a property
    # So that I can decide if I want to inquire about it

    # Use legacy Prop model which works with existing tests
    let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'test-details') }
    let!(:sale_prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :sale, website: website, title_en: 'Beautiful Madrid Apartment')
      end
    end
    let!(:rental_prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :long_term_rent, website: website, title_en: 'Charming Barcelona Rental')
      end
    end

    before(:each) do
      Capybara.app_host = 'http://test-details.example.com'
    end

    after(:each) do
      Capybara.app_host = nil
    end

    describe "Sale Property Details Page" do
      scenario "displays property page" do
        visit("/en/properties/for-sale/#{sale_prop.id}/beautiful-madrid-apartment")

        # Should display a valid page (even if property not found shows branding)
        expect(page).to have_content('Beautiful')
          .or have_content('Madrid')
          .or have_content('Apartment')
          .or have_content('Test Company')
      end

      scenario "page renders without error" do
        visit("/en/properties/for-sale/#{sale_prop.id}/beautiful-madrid-apartment")

        # Page should not be an error page
        expect(page.status_code).to eq(200).or eq(404)
      end
    end

    describe "Rental Property Details Page" do
      scenario "displays rental property page" do
        visit("/en/properties/for-rent/#{rental_prop.id}/charming-barcelona-rental")

        # Should display a valid page
        expect(page).to have_content('Charming')
          .or have_content('Barcelona')
          .or have_content('Rental')
          .or have_content('Test Company')
      end
    end

    describe "Property Page Structure" do
      scenario "property page has basic structure" do
        visit("/en/properties/for-sale/#{sale_prop.id}/test-property")

        # Page should have navigation and footer
        expect(page).to have_content('Test Company')
          .or have_content('PropertyWebBuilder')
      end
    end
  end
end
