require 'rails_helper'

module Pwb
  RSpec.describe "Themes", type: :request do
    before(:all) do
      # @agency = Agency.last || FactoryGirl.create(:pwb_agency, company_name: 'my re')
      # in /pwb/app/controllers/pwb/application_controller.rb, theme gets set against website instance
      @website = FactoryGirl.create(:pwb_website)
      # factorygirl ensures unique_instance of website is used
    end


    context 'when theme is set' do
      it 'uses correct theme' do
        @website.theme_name = "berlin"
        @website.save!
        get "/"
        view_paths =  @controller.view_paths.map {|vp| vp.to_s}
        expect(view_paths).to include  "#{Pwb::Engine.root}/app/themes/berlin/views"
      end
    end

    context 'when no theme is set' do
      it 'uses default theme' do
        @website.theme_name = nil
        @website.save!
        get "/"
        view_paths =  @controller.view_paths.map {|vp| vp.to_s}
        expect(view_paths).to include  "#{Pwb::Engine.root}/app/themes/default/views"
      end
    end

    context 'when theme_name is empty' do
      it 'uses default theme' do
        @website.theme_name = ""
        @website.save!
        get "/"
        view_paths =  @controller.view_paths.map {|vp| vp.to_s}
        expect(view_paths).to include  "#{Pwb::Engine.root}/app/themes/default/views"
      end
    end


    after(:all) do
      @website.destroy
    end
  end
end
