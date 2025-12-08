require "rails_helper"

RSpec.describe "pwb/pages/show", type: :view do
  include Pwb::ApplicationHelper

  let(:website) { FactoryBot.create(:pwb_website) }

  before(:each) do
    view.extend Pwb::ApplicationHelper
    @controller.prepend_view_path "#{Rails.root}/app/themes/default/views/"

    ActsAsTenant.with_tenant(website) do
      @page = FactoryBot.create(:pwb_page, website: website)
    end

    allow(@page.main_link).to receive("link_title").and_return("hello")
    assign(:content_to_show, [])
    assign(:page_contents_for_edit, [])
  end

  it "renders content for page successfully" do
    render
    expect(rendered).to have_selector(".container")
  end

  # AFAIK cleanup not needed with before(:each) blocks
  # after(:each) do
  #   @page.destroy
  # end
end
