require 'rails_helper'

RSpec.describe 'layouts/pwb/application', type: :view do
  # include Pwb::ApplicationHelper

  before do
    view.extend Pwb::Engine.routes.url_helpers
    view.extend Pwb::ApplicationHelper
  end


  before(:each) do
    assign(:current_agency, Pwb::Agency.create!({company_name: 'test'}))
    assign(:current_website, Pwb::Website.unique_instance)
    assign(:footer_content, OpenStruct.new)
      # create!({company_name: 'test'}))
    assign(:sections, [
             Pwb::Section.create!({link_path: 'about_us_path', link_key: 'aboutUs'}),
             Pwb::Section.create!({link_path: 'contact_us_path', link_key: 'contactUs'})
    ])
  end

  it 'renders navbar-header' do
    render

    expect(rendered).to have_selector(".navbar-header")
  end
end
