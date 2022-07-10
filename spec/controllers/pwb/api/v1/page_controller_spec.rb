require "rails_helper"

module Pwb
  RSpec.describe Api::V1::PageController, type: :controller do
    routes { Rails.application.routes }

    context "without signing in" do
      before(:each) do
        sign_in_stub nil
      end
      it "should not have a current_user" do
        expect(subject.current_user).to eq(nil)
      end
    end

    context "with non_admin user" do
      login_non_admin_user

      it "should have a current_user" do
        expect(subject.current_user).to_not eq(nil)
      end

      describe "GET #show" do
        it "returns unauthorized status" do
          get :show, params: {
                   page_name: "home",
                 }

          expect(response.status).to eq(422)
        end
      end
    end

    context "with admin user" do
      login_admin_user
      before do
        # let!(:page) { FactoryBot.create(:pwb_page, :home_page) }
        @page = FactoryBot.create(:page_with_content_html_page_part,
                                  slug: "home")
        page_part = @page.page_parts.first
        page_part.template = '<div>{{ page_part["main_content"]["content"] %> }}</div>'
        page_part.save!
      end

      it "should have a current_user" do
        expect(subject.current_user).to_not eq(nil)
      end

      describe "should save_page_fragment correctly" do
        it "returns error status when no params are provided" do
          post :save_page_fragment
          expect(response.status).to eq(422)
        end

        it "saves page content when params are correct" do
          post :save_page_fragment, params: {
                                 fragment_details: {
                                   locale: "en",
                                   page_part_key: "content_html",
                                   blocks: {
                                     main_content: {
                                       content: "<p>Hola.</p>",
                                     },
                                   },
                                 },
                                 page_slug: "home",
                               }

          expect(response.status).to eq(200)

          result_as_json = JSON.parse(response.body)

          expect(result_as_json["html"]).to eq("<div><p>Hola.</p></div>")
        end
      end

      describe "GET #show" do
        it "returns correct agency and default setup info" do
          get :show, params: {
                   page_name: "home",
                 }
          # , format: :json
          expect(response.status).to eq(200)
          expect(response.content_type).to eq("application/json")

          result_as_json = JSON.parse(response.body)

          expect(result_as_json).to have_key("show_in_top_nav")
          expect(result_as_json["slug"]).to eq("home")
          # expect(result_as_json['setup']['name']).to eq('default')
        end
      end
    end
  end
end
