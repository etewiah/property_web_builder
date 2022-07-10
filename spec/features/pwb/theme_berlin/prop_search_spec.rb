require 'rails_helper'

module Pwb
  RSpec.describe "Berlin theme property search", type: :feature, js: true do
    # pending " while investigating timeout issue with capybara "

    before(:all) do
      @agency = FactoryBot.create(:pwb_agency, :theme_berlin, company_name: 'my re')
      # @agency.theme_name = "berlin"
      # @agency.save!

      @prop_for_long_term_rent = FactoryBot.create(
        :pwb_prop,
        :long_term_rent,
        price_rental_monthly_current_cents: 100_000,
        reference: "ref_pfltr"
      )
    end

    scenario 'property search works' do
      visit('/en/rent')

      # puts current_url
      # require 'pry'; binding.pry
      # save_and_open_page
      # save_and_open_screenshot

      property_search_page = Pages::PropertySearch.new
      # /Users/etewiah/Ed/sites-2016-oct-pwb/pwb/spec/support/features/pages/property_search.rb
      # have_search_result_count from has_search_result_count method in above
      expect(property_search_page).to have_search_result_count(Prop.visible.for_rent.count)
      # (".property-item", count: Prop.visible.for_rent.count)

      property_search_page.search_rentals('2,500')
      expect(property_search_page).to have_search_result_count(Prop.visible.for_rent.for_rent_price_from(250_000).count)
      # expect(page).to have_css(".property-item", count:  Prop.visible.for_rent.for_rent_price_from(250000).count)
    end

    after(:all) do
      @agency.destroy
      @prop_for_long_term_rent.destroy
      # @prop_for_sale.destroy
    end
  end
end
