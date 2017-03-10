require 'rails_helper'
# TODO - use page object here too
module Pwb
  RSpec.describe "Default theme property search", type: :feature, js: true do
    before(:all) do
      @agency = FactoryGirl.create(:pwb_agency, :theme_default, company_name: 'my re')
      # @agency.theme_name = "berlin"
      # @agency.save!

      @prop_for_long_term_rent = FactoryGirl.create(
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
      expect(page).to have_css(".property-item", count: Prop.visible.for_rent.count)
      # Capybara.ignore_hidden_elements = false
      # passing visible: false below would be like setting above
      select('2,500', from: 'search_for_rent_price_from', visible: false)

      click_button('Search')
      expect(page).to have_css(".property-item", count:  Prop.visible.for_rent.for_rent_price_from(250000).count)
      # expect(current_path).to eq("/en")
    end

    after(:all) do
      @agency.destroy
      @prop_for_long_term_rent.destroy
      # @prop_for_sale.destroy
    end
  end
end
