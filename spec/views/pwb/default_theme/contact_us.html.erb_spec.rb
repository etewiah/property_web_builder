require 'rails_helper'

RSpec.describe 'pwb/sections/contact_us', type: :view do
  include Pwb::ApplicationHelper

  before do
    # @website = FactoryBot.create(:pwb_website)
    view.extend Pwb::ApplicationHelper
    view.extend Pwb::ComponentHelper
    # https://github.com/rspec/rspec-rails/issues/396
    # https://stackoverflow.com/questions/19282240/rspec-view-tests-cant-find-partials-that-are-in-base-namespace
    # can use below to test other views
    # view.lookup_context.view_paths.push 'app/themes/default/views/'
    @controller.prepend_view_path "#{Pwb::Engine.root}/app/themes/default/views/"
  end


  before(:each) do
    # assign(:content_to_show, ["form_and_map"])
    assign(:current_agency, FactoryBot.create(:pwb_agency, company_name: 'my re'))
    assign(:page, FactoryBot.create(:contact_us_with_rails_page_part))
  end

  it 'renders contact-us form successfully' do
    render
    expect(rendered).to have_selector("form.mi_form")
  end
end
