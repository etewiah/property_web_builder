require 'rails_helper'

module Pwb
  RSpec.describe FirebaseLoginController, type: :controller do
    routes { Rails.application.routes }

    describe "GET #index" do
      it "renders the index template" do
        get :index
        expect(response).to render_template("pwb/firebase_login/index")
      end

      it "sets current agency" do
        get :index
        expect(assigns(:current_agency)).to_not be_nil
      end
    end
  end
end
