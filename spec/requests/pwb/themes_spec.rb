require 'rails_helper'

module Pwb
  RSpec.describe "Themes", type: :request do
    before(:all) do
      @agency = Agency.last || FactoryGirl.create(:pwb_agency, company_name: 'my re')

    end


    context 'when theme is set' do
      it 'uses correct theme' do
        @agency.theme_name = "berlin"
        @agency.save!
        get "/"
        view_paths =  @controller.view_paths.map {|vp| vp.to_s}
        # byebug
        expect(view_paths).to include  "#{Pwb::Engine.root}/app/themes/berlin/views"
      end
    end

    context 'when no theme is set' do
      it 'uses default theme' do
        @agency.theme_name = nil
        @agency.save!
        get "/"
        view_paths =  @controller.view_paths.map {|vp| vp.to_s}
        expect(view_paths).to include  "#{Pwb::Engine.root}/app/themes/default/views"
      end
    end



    after(:all) do
      @agency.destroy
    end
  end
end
