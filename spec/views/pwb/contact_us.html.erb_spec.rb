require 'rails_helper'

RSpec.describe 'pwb/sections/contact_us', type: :view do
  include Pwb::ApplicationHelper

  before do
    view.extend Pwb::ApplicationHelper
  end

  before(:each) do
    assign(:current_agency, FactoryGirl.create(:pwb_agency, company_name: 'my re'))
  end

  it 'renders contact-us form successfully' do
    render
    expect(rendered).to have_selector("form.mi_form")
  end
end
