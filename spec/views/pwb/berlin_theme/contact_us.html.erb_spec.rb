require "rails_helper"

RSpec.describe "pwb/sections/contact_us", type: :view do
  include Pwb::ApplicationHelper

  let(:website) { FactoryBot.create(:pwb_website, subdomain: 'contact-view-test', theme_name: 'brisbane') }

  before do
    view.extend Pwb::ApplicationHelper
    view.extend Pwb::ComponentHelper
    # Use brisbane theme (berlin theme doesn't exist)
    @controller.prepend_view_path "#{Rails.root}/app/themes/brisbane/views/"
  end

  before(:each) do
    ActsAsTenant.with_tenant(website) do
      agency = FactoryBot.create(:pwb_agency, company_name: "my re", website: website)
      page = FactoryBot.create(:contact_us_with_rails_page_part, website: website)
      assign(:current_agency, agency)
      assign(:page, page)
    end
  end

  it "renders contact-us form successfully" do
    render
    # Different themes use different form classes
    expect(rendered).to have_selector("form")
  end
end
