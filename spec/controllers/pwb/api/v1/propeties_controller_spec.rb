require 'rails_helper'

module Pwb
  RSpec.describe Api::V1::PropertiesController, type: :controller do
    routes { Pwb::Engine.routes }
    context 'with admin user' do
      login_admin_user

      let(:bulk_create_input ) do
        File.read(fixture_path + "/params/bulk_create.json")
      end

      describe 'bulk create' do
        it 'creates multiple properties' do
          bulk_create_params = {
            propertiesJSON: bulk_create_input
          }


          expect{
            post :bulk_create, params: bulk_create_params
          }.to change(Prop, :count).by(4)
          expect(response.status).to eq(200)
          expect(response.content_type).to eq('application/json')

          # expect(I18n.t(I18n::Backend::ActiveRecord::Translation.last.key)).to eq(propertiesJSON[:i18n_value])
        end
      end
    end
  end
end
