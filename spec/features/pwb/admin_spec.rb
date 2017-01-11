require 'rails_helper'

module Pwb
  RSpec.describe "Prop Search", type: :feature, js: true do
    before(:all) do
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
      @prop_for_long_term_rent = FactoryGirl.create(
        :pwb_prop,
        :long_term_rent,
        price_rental_monthly_current_cents: 100_000,
        reference: "ref_pfltr"
      )
    end

    scenario 'admin works works' do
      visit('/admin')
      # puts current_url
      # require 'pry'; binding.pry
      # save_and_open_page
      fill_in('Email', with: @admin_user.email)
      fill_in('Password', with: @admin_user.password)
      click_button('Sign in')
      visit('/admin')
      # byebug
      expect(page).to have_css(".main-menu", count: 1)

      # Capybara.ignore_hidden_elements = false
      # passing visible: false below would be like setting above
      # select('2000', from: 'search_for_rent_price_from', visible: false)
      # click_button('Search')
      # expect(page).to have_css(".property-item", count: 0)
      # expect(current_path).to eq("/en")
    end

    # after(:all) do
    #   @prop_for_long_term_rent.destroy
    # end
  end
end
