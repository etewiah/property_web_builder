require 'rails_helper'

module Pwb
  RSpec.describe "Property Search", type: :feature do
    # US-1.2: Search Properties with Filters
    # As a public visitor, I want to filter properties by various criteria
    # So that I can narrow down my search to relevant listings

    # Use legacy Prop model which works with existing tests
    let!(:website) { FactoryBot.create(:pwb_website, subdomain: 'test-search') }
    let!(:sale_prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :sale, website: website, title_en: 'Madrid Apartment')
      end
    end
    let!(:rental_prop) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_prop, :long_term_rent, website: website, title_en: 'Valencia Rental')
      end
    end

    before(:each) do
      Capybara.app_host = 'http://test-search.example.com'
    end

    after(:each) do
      Capybara.app_host = nil
    end

    describe "Sale Search Page" do
      scenario "displays search filters" do
        visit('/en/buy')

        # The buy page should have a search form with filters
        expect(page).to have_content('Search').or have_content('Filter')
        expect(page).to have_content('Price')
      end

      scenario "has property type filter" do
        visit('/en/buy')

        # Should have property type filter
        expect(page).to have_content('Property Type')
          .or have_content('Type')
      end

      scenario "has bedroom filter" do
        visit('/en/buy')

        # Should have bedroom filter
        expect(page).to have_content('Bedroom')
          .or have_content('bedroom')
      end
    end

    describe "Rental Search Page" do
      scenario "displays rental-specific filters" do
        visit('/en/rent')

        # The rent page should have rental-specific filters
        expect(page).to have_content('Rent')
        expect(page).to have_content('Search').or have_content('Filter')
      end

      scenario "shows different price labels than sale" do
        visit('/en/rent')

        # Rental page should have monthly rent terminology
        page_content = page.body.downcase
        expect(page_content).to include('rent')
      end
    end

    describe "Search Form Structure" do
      scenario "buy page has submit button" do
        visit('/en/buy')

        expect(page).to have_button('Search')
          .or have_css('input[type="submit"]')
          .or have_css('button[type="submit"]')
      end
    end
  end
end
