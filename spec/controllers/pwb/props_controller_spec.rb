require 'rails_helper'

module Pwb
  RSpec.describe PropsController, type: :controller do
    routes { Pwb::Engine.routes }

    # describe 'GET #show_for_rent' do

    #   it 'renders correct template' do
    #     # byebug
    #     expect(get(:show_for_rent)).to render_template('pwb/welcome/show_for_rent')
    #     # above results in error:  
    #     # ActionController::UrlGenerationError Exception: No route matches {:action=>"prop_show_for_rent", :controller=>"pwb/props"}
    #   end
    # end
  end
end
