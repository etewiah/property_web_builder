require "rails_helper"

RSpec.describe "pwb/sections/contact_us", type: :view do
  include Pwb::ApplicationHelper

  let(:website) { FactoryBot.create(:pwb_website, subdomain: 'default-contact-test', theme_name: 'default') }

  before do
    Pwb::Current.reset
    view.extend Pwb::ApplicationHelper
    view.extend Pwb::ComponentHelper
    @controller.prepend_view_path "#{Rails.root}/app/themes/default/views/"
  end

  before(:each) do
    ActsAsTenant.with_tenant(website) do
      @agency = FactoryBot.create(:pwb_agency, company_name: "my re", website: website)
      @page = FactoryBot.create(:contact_us_with_rails_page_part, website: website)
    end
    assign(:current_agency, @agency)
    assign(:page, @page)
  end

  it "renders contact-us form successfully" do
    render
    # Default theme uses Tailwind CSS form with space-y-4 class
    expect(rendered).to have_selector("form.space-y-4")
  end
end
