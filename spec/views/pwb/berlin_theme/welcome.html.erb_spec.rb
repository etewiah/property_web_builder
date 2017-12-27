require 'rails_helper'

RSpec.describe 'pwb/welcome/index', type: :view do
  include Pwb::ApplicationHelper
  include Pwb::ImagesHelper
  before do
    view.extend Pwb::ApplicationHelper
    view.extend Pwb::ImagesHelper
    @current_website = FactoryGirl.create(:pwb_website)
    @page_content = FactoryGirl.create(:pwb_content, :main_content)
    # factorygirl ensures unique_instance of website is used

    # ActionController::Base.prepend_view_path "#{Pwb::Engine.root}/app/themes/berlin/views/"
    # replaced above in spec_helper with below
    @controller.prepend_view_path "#{Pwb::Engine.root}/app/themes/berlin/views/"
# byebug
    assign(:current_agency, Pwb::Agency.unique_instance)
    # assign(:about_us, Pwb::Content.create!({key: 'aboutUs'}))
    # assign(:carousel_items, [
    #          Pwb::Content.create!,
    #          Pwb::Content.create!
    # ])
    # assign(:content_area_cols, [
    #          Pwb::Content.create!,
    #          Pwb::Content.create!
    # ])
    assign(:properties_for_sale, [])
    assign(:properties_for_rent, [])
  end

  it 'renders index successfully' do
    assign(:content_to_show, [@page_content.raw])
    render
    expect(rendered).to include 'Sell Your Property'
    # assert_select "form[action=?][method=?]", welcome_path(@welcome), "post" do
    # end
  end

end
