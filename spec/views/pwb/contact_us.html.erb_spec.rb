require 'rails_helper'

RSpec.describe 'pwb/sections/contact_us', type: :view do
  include Pwb::ApplicationHelper

  before do
    view.extend Pwb::ApplicationHelper
  end

  before(:each) do
    assign(:current_agency, Pwb::Agency.create!({company_name: 'test'}))
  end

  it 'renders contact-us form successfully' do
    render
    expect(rendered).to have_selector("form.mi_form")
  end


end
