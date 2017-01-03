require 'rails_helper'

module Pwb
  RSpec.describe "Sessions", type: :request do
    before(:all) do
      @agency = FactoryGirl.create(:pwb_agency, company_name: 'my re')
      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    end

    it "signs user in and out" do
      sign_in @admin_user
      get pwb.admin_path
      # byebug
      expect(controller.current_user).to eq(@admin_user)

      sign_out @admin_user
      get "/admin"
      # expect(controller.current_user).to be_nil
      expect(response).to redirect_to(pwb.new_user_session_path)
    end

    after(:all) do
      @agency.destroy
      @admin_user.destroy
    end
  end
end
