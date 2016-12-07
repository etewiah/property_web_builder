require 'rails_helper'

module Pwb
  RSpec.describe "Sessions", type: :request do

    it "signs user in and out" do
      user = User.create!(email: "user@example.org", password: "very-secret")

      sign_in user
      get pwb.admin_path
      # byebug
      expect(controller.current_user).to eq(user)

      sign_out user
      get "/admin"
      # expect(controller.current_user).to be_nil
      expect(response).to redirect_to(pwb.new_user_session_path)
    end

  end

end
