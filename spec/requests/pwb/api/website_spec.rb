require 'rails_helper'



module Pwb
  RSpec.describe 'Website API' do
    # FactoryGirl.create_list(:message, 10)
    before(:all) do
      @website = FactoryGirl.create(:pwb_website, company_display_name: 'my re')
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin:true)
    end


    describe "PUT /api/v1/website" do
      it "updates website" do
        sign_in @admin_user

        website_params = {
          "website": {
            "company_display_name": 'my re',
            "supported_locales": ["fr","es"],
            "social_media": {
              "twitter": "http://twitter.com",
              "youtube": ""
            },
            "raw_css": "",
            "style_variables": {
              "primary_color": "#3498db",
              "secondary_color": "#563d7c",
              "action_color": "green",
              "body_style": "siteLayout.boxed",
              "theme": "light"
            }
          }
        }.to_json

        request_headers = {
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }


        #  ActionDispatch::IntegrationTest HTTP request methods will accept only
        # the following keyword arguments in future Rails versions:
        # params, headers, env, xhr, as

        # put '/profile',
        #   params: { id: 1 },
        #   headers: { 'X-Extra-Header' => '123' },
        #   env: { 'action_dispatch.custom' => 'custom' },
        #   xhr: true,
        #   as: :json

        put "/api/v1/website", params: website_params, headers: request_headers
        expect(response.status).to eq 200 # successful
        @website.reload
        expect(@website.supported_locales).to eq ["fr","es"]
        social_media_expectation = {"twitter"=>"http://twitter.com", "youtube"=>""}
        style_variables_expectation = {"primary_color"=>"#3498db", "secondary_color"=>"#563d7c", "action_color"=>"green", "body_style"=>"siteLayout.boxed", "theme"=>"light"}
        expect(@website.social_media).to eq social_media_expectation
        expect(@website.style_variables).to eq style_variables_expectation
      end
    end

    after(:all) do
      @website.destroy
      @admin_user.destroy
    end

  end

end
