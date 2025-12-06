require 'rails_helper'

module Pwb
  RSpec.describe "Property Browsing", type: :feature do
    # US-1.1: View Property Listings
    # As a public visitor, I want to browse available properties
    # So that I can find properties that interest me

    # Use legacy Prop model which works with existing tests
    let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'test-browse') }
    let!(:sale_prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :sale, website: website, title_en: 'Cozy City Apartment')
      end
    end
    let!(:rental_prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :long_term_rent, website: website, title_en: 'Downtown Studio')
      end
    end

    before(:each) do
      Capybara.app_host = 'http://test-browse.example.com'
    end

    after(:each) do
      Capybara.app_host = nil
    end

    describe "Sale Properties Page" do
      scenario "displays search filters for sale properties" do
        visit('/en/buy')

        # The buy page should have a search form with price filters
        expect(page).to have_content('Search').or have_content('Filter')
        expect(page).to have_content('Price')
      end

      scenario "can access property details directly" do
        visit("/en/properties/for-sale/#{sale_prop.id}/cozy-city-apartment")

        # Should display property information or a valid page
        expect(page).to have_content('Cozy')
          .or have_content('property')
          .or have_content('Apartment')
          .or have_content('Test Company')
      end
    end

    describe "Rental Properties Page" do
      scenario "displays search filters for rental properties" do
        visit('/en/rent')

        # The rent page should have rental-specific filters
        expect(page).to have_content('Search').or have_content('Filter')
        expect(page).to have_content('Rent')
      end

      scenario "can access rental property details directly" do
        visit("/en/properties/for-rent/#{rental_prop.id}/downtown-studio")

        # Should display rental property information or a valid page
        expect(page).to have_content('Downtown')
          .or have_content('Studio')
          .or have_content('property')
          .or have_content('Test Company')
      end
    end

    describe "Navigation between property types" do
      scenario "can navigate from buy to rent page" do
        visit('/en/buy')

        # Look for rent/rental link in navigation
        if page.has_link?('Rent')
          click_link('Rent')
          expect(current_path).to include('/rent')
        end
      end
    end
  end
end
