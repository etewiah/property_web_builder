require "rails_helper"

RSpec.describe "pwb/welcome/index", type: :view do
  include Pwb::ApplicationHelper
  include Pwb::ImagesHelper
  include Pwb::ComponentHelper

  before do
    view.extend Pwb::ApplicationHelper
    view.extend Pwb::ImagesHelper
    view.extend Pwb::ComponentHelper
    # @current_website = FactoryBot.create(:pwb_website)
    @page = FactoryBot.create(:page_with_content_html_page_part,
                              slug: "home")
    # @page_content = FactoryBot.create(:pwb_content, :main_content)
    # factorygirl ensures unique_instance of website is used

    # ActionController::Base.prepend_view_path "#{Rails.root}/app/themes/default/views/"
    # replaced above in spec_helper with below
    @controller.prepend_view_path "#{Rails.root}/app/themes/default/views/"

    # assign(:current_agency, Pwb::Agency.unique_instance)

    assign(:properties_for_sale, [])
    assign(:properties_for_rent, [])
  end

  it "renders index successfully" do
    # assign(:content_to_show, [@page_content.raw])
    assign(:page, @page)
    # byebug
    render

    expect(rendered).to include "Sell Your Property"
    # assert_select "form[action=?][method=?]", welcome_path(@welcome), "post" do
    # end
  end
end
