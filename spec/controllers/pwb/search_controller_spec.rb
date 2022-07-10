require 'rails_helper'

module Pwb
  RSpec.describe SearchController, type: :controller do
    routes { Pwb::Engine.routes }
    # let(:prop_for_long_term_rent) {
    #   FactoryBot.create(:pwb_prop, :long_term_rent,
    #                      price_rental_monthly_current_cents: 100_000)
    # }
    # let(:prop_for_sale) {
    #   FactoryBot.create(:pwb_prop, :sale,
    #                      price_sale_current_cents: 10_000_000)
    # }

    describe 'GET #rent' do
      it '' do
        get :rent, params: {}
        expect(assigns(:prices_from_collection)).to eq(Website.unique_instance.rent_price_options_from)
        expect(assigns(:prices_till_collection)).to eq(Website.unique_instance.rent_price_options_till)
      end
    end

    describe 'GET #buy' do
      it '' do
        get :buy, params: {}
        expect(assigns(:prices_from_collection)).to eq(Website.unique_instance.sale_price_options_from)
        expect(assigns(:prices_till_collection)).to eq(Website.unique_instance.sale_price_options_till)
      end

      # it 'renders correct template' do
      #   expect(get(:buy, params: {
      #   })).to render_template(["pwb/search/buy", "pwb/_header", "pwb/_footer", "paloma/_hook"])
      # end
    end
  end
end
