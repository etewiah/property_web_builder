require 'rails_helper'

RSpec.describe 'layouts/pwb/application', type: :view do
  # include Pwb::ApplicationHelper
  pending "Find change in Devise resulting in error message when current_user is encountered"
  # spt 2017 error message is
  # "Devise could not find the `Warden::Proxy` instance on your request environment"


  # before do
  #   view.extend Pwb::Engine.routes.url_helpers
  #   view.extend Pwb::ApplicationHelper
  #   view.extend Pwb::CssHelper
  #   view.extend Pwb::NavigationHelper
  # end

  # before(:each) do
  #   # assign(:current_user, nil)
  #   # spt 2017: tried above to fix devise error - no luck..

  #   assign(:current_agency, FactoryBot.create(:pwb_agency, company_name: 'my re'))
  #   # Pwb::Agency.create!({company_name: 'test'}))
  #   assign(:current_website, Pwb::Website.unique_instance)
  #   assign(:footer_content, OpenStruct.new)
  #   assign(:sections, [])
  #   # below will throw an error if section with link_key already exists
  #   # assign(:sections, [
  #   #          Pwb::Section.create!({link_path: 'about_us_path', link_key: 'aboutUs'}),
  #   #          Pwb::Section.create!({link_path: 'contact_us_path', link_key: 'contactUs'})
  #   # ])
  # end

  # it 'renders navbar-header' do
  #   render
  #   expect(rendered).to have_selector(".navbar-header")
  # end
end
