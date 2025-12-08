require "rails_helper"

RSpec.describe "pwb/welcome/index", type: :view do
  include Pwb::ApplicationHelper
  include Pwb::ImagesHelper
  include Pwb::ComponentHelper

  let(:website) { FactoryBot.create(:pwb_website, subdomain: 'welcome-view-test', theme_name: 'default') }

  before do
    Pwb::Current.reset
    view.extend Pwb::ApplicationHelper
    view.extend Pwb::ImagesHelper
    view.extend Pwb::ComponentHelper

    ActsAsTenant.with_tenant(website) do
      @page = FactoryBot.create(:page_with_content_html_page_part, slug: "home", website: website)
      @agency = FactoryBot.create(:pwb_agency, website: website)
    end

    # Use default theme (berlin doesn't exist)
    @controller.prepend_view_path "#{Rails.root}/app/themes/default/views/"

    assign(:current_agency, @agency)
    assign(:properties_for_sale, [])
    assign(:properties_for_rent, [])
  end

  it "renders index successfully" do
    assign(:page, @page)
    render
    expect(rendered).to include "Sell Your Property"
  end
end
