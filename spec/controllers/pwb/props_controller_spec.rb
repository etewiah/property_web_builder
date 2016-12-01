require 'rails_helper'

module Pwb
  RSpec.describe PropsController, type: :controller do
    routes { Pwb::Engine.routes }
    let(:prop_for_long_term_rent) { FactoryGirl.create(:pwb_prop, :available_for_long_term_rent,
                                                       price_rental_monthly_current_cents: 100000) }
    let(:prop_for_sale) { FactoryGirl.create(:pwb_prop, :available_for_sale,
                                             price_sale_current_cents: 10000000) }

    describe 'GET #show_for_rent' do
      it 'renders correct template' do
        expect(get(:show_for_rent, params: {
                     id: prop_for_long_term_rent.id,
                     url_friendly_title: "tt"
        })).to render_template('pwb/themes/standard/props/show')
      end
    end

    describe 'GET #show_for_sale' do
      context 'with id of for sale prop' do
        it 'renders correct template' do
          expect(get(:show_for_sale, params: {
                       id: prop_for_sale.id,
                       url_friendly_title: "tt"
          })).to render_template('pwb/themes/standard/props/show')
        end
      end
      context 'with id of for rent prop' do
        it 'renders correct template' do
          expect(get(:show_for_sale, params: {
                       id: prop_for_long_term_rent.id,
                       url_friendly_title: "tt"
          })).to render_template('pwb/props/not_found')
        end
      end
    end

  end
end
