require 'rails_helper'

RSpec.describe 'pwb/pages/show', type: :view do
  include Pwb::ApplicationHelper

  before do
    # @website = FactoryGirl.create(:pwb_website)
    view.extend Pwb::ApplicationHelper
    # https://github.com/rspec/rspec-rails/issues/396
    # https://stackoverflow.com/questions/19282240/rspec-view-tests-cant-find-partials-that-are-in-base-namespace
    # can use below to test other views
    # view.lookup_context.view_paths.push 'app/themes/berlin/views/'
    # -already add below in spec_helper
    # ActionController::Base.prepend_view_path "#{Pwb::Engine.root}/app/themes/default/views/"
    @page = FactoryGirl.create(:pwb_page)
  end



  before(:each) do
    # assign(:page, OpenStruct.new(page_title: "ttt"))
    # assign(:current_agency, FactoryGirl.create(:pwb_agency, company_name: 'my re'))
    assign(:content_to_show, [])
  end

  it 'renders content for page successfully' do
    render
    expect(rendered).to have_selector(".container")
  end

end
