require 'rails_helper'

module Pwb
  RSpec.describe AdminPanelController, type: :controller do
    routes { Pwb::Engine.routes }

    # because auth happens in routes.rb, unable to test below from controller
    # it "blocks unauthenticated access" do
    #   sign_in_stub nil

    #   get :show
    #   expect(response).to redirect_to(new_user_session_path)
    # end

    it "allows authenticated access" do
      sign_in_stub

      get :show
      expect(response).to be_success
    end


    context 'without signing in' do
      before(:each) do
        # @request.env["devise.mapping"] = Devise.mappings[:user]
        # user = FactoryGirl.create(:pwb_user, email: 'ad@pwb.com', password: '123456')
        sign_in_stub nil
      end
      it "should not have a current_user" do
        expect(subject.current_user).to eq(nil)
      end

    end

    context 'with admin user' do
      login_admin_user
      # before(:each) do
      #   sign_in_stub
      # end

      it "should have a current_user" do
        # note the fact that you should remove the "validate_session" parameter if this was a scaffold-generated controller
        expect(subject.current_user).to_not eq(nil)
      end

      describe 'GET #show' do
        it 'renders correct template' do
          expect(get(:show)).to render_template('pwb/admin_panel/show')
        end
      end
    end

  end
end
