require "rails_helper"

module Pwb
  RSpec.describe Api::V1::TranslationsController, type: :controller do
    routes { Rails.application.routes }
    context "with admin user" do
      login_admin_user

      describe "PUT" do
        it "creates correct translation" do
          # below will throw an error if no translations exist
          # original_pt_count = I18n.t("propertyTypes").count
          new_translation_params = {
            locale: "en",
            i18n_value: "Flat",
            i18n_key: "flat",
            batch_key: "property-types",
          }
          put :create_translation_value, params: new_translation_params
          expect(response.status).to eq(200)
          # expect(response.content_type).to eq("application/json")

          expect(I18n::Backend::ActiveRecord::Translation.last.key).to eq(new_translation_params[:batch_key].underscore.camelcase(:lower) + "." + new_translation_params[:i18n_key])
          # result = JSON.parse(response.body)
          # expect(I18n.t("propertyTypes").count).to eq(original_pt_count + 1)
          expect(I18n.t(I18n::Backend::ActiveRecord::Translation.last.key)).to eq(new_translation_params[:i18n_value])
        end
      end
      describe "GET #get_by_batch" do
        it "renders correct json" do
          get :get_by_batch, params: {
                               batch_key: "property-types",
                             }
          # , format: :json

          expect(response.status).to eq(200)
          # expect(response.content_type).to eq("application/json")

          result = JSON.parse(response.body)
          expect(result).to have_key("batch_key")
          expect(result).to have_key("translations")
          # expect(result['agency']['company_name']).to eq(agency.company_name)
        end
      end
    end
  end
end
