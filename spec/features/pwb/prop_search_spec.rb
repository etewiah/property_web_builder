require 'rails_helper'

module Pwb
  RSpec.describe "Prop Search", type: :feature, js: true do
    before(:all) do

      # @agency = FactoryGirl.create(:pwb_agency, company_name: 'my re')
      # @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin:true)
      @prop_for_long_term_rent =  FactoryGirl.create(
        :pwb_prop,
        :long_term_rent,
        price_rental_monthly_current_cents: 100000,
        :reference => "ref_pfltr"
      )
      # @prop_for_sale =  FactoryGirl.create(
      #   :pwb_prop,
      #   :sale,
      #   price_sale_current_cents: 10000000,
      #   :reference => "ref_pf"
      # )
    end


    scenario 'property search works' do
      visit('/en/rent')
      # puts current_url
      # require 'pry'; binding.pry
      # save_and_open_page

      expect(page).to have_css(".property-item", :count => 1)

      # Capybara.ignore_hidden_elements = false
      # passing visible: false below would be like setting above
      select('2000', from: 'search_for_rent_price_from', visible: false)
      click_button('Search')
      expect(page).to have_css(".property-item", :count => 0)
      # expect(current_path).to eq("/en")
    end


    after(:all) do
      # @agency.destroy
      # @admin_user.destroy
      @prop_for_long_term_rent.destroy
      # @prop_for_sale.destroy
    end
  end
end
