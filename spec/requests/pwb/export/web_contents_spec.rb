require 'rails_helper'

module Pwb
  RSpec.describe 'Export web contents' do
    before(:all) do
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin:true)
    end

    context 'with signed in admin user' do
      describe "GET /export/web_contents/all" do
        it "is successful" do
          sign_in @admin_user

          get "/export/web_contents/all"
          expect(response.status).to eq 200 # successful
          # expect(response.body).to have_json_path("agency")
        end
      end
    end

    after(:all) do
      @admin_user.destroy
    end
  end
end
