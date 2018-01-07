require 'rails_helper'

RSpec.describe 'pwb/pages/show', type: :view do
  include Pwb::ApplicationHelper

  before(:each) do
    # @website = FactoryGirl.create(:pwb_website)
    # view.extend below will not work in a before(:all) block
    view.extend Pwb::ApplicationHelper
    # https://github.com/rspec/rspec-rails/issues/396
    # https://stackoverflow.com/questions/19282240/rspec-view-tests-cant-find-partials-that-are-in-base-namespace
    # can use below to test other views
    # view.lookup_context.view_paths.push 'app/themes/berlin/views/'
    @controller.prepend_view_path "#{Pwb::Engine.root}/app/themes/berlin/views/"
    @page = FactoryGirl.create(:pwb_page)

    # in some test runs a whole load of  Pwb::Link model objects are getting created....  - not sure from where
    # but in others they don't exist so need to add below
    allow(@page.main_link).to receive("link_title").and_return("hello")
    # main_link = double(:main_link, link_title: "hello")

    # assign(:current_agency, FactoryGirl.create(:pwb_agency, company_name: 'my re'))
    assign(:content_to_show, [])
  end

  it 'renders content for page successfully' do
    render
    expect(rendered).to have_selector(".container")
  end

  # AFAIK cleanup not needed with before(:each) blocks
  # after(:each) do
  #   @page.destroy
  # end
end
