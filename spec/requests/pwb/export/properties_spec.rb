```ruby
require 'rails_helper'

module Pwb
  RSpec.describe 'Export web contents' do
    before do
      # require_relative '../../../../app/controllers/pwb/export/properties_controller'
      puts "Ancestors: #{Pwb::Export::PropertiesController.ancestors}"
      @admin_user = FactoryBot.create(:pwb_user, :admin)
    end

    context 'with signed in admin user' do
      describe "GET /export/properties" do
        it "is successful" do
          sign_in @admin_user

          get "/export/properties"
          puts response.body
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
