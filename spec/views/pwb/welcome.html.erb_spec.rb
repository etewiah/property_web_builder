require 'rails_helper'

RSpec.describe "pwb/welcome/index", type: :view do
  # before(:each) do
  #   @content = assign(:content, Pwb::Content.create!())
  # end

  before(:each) do
    assign(:carousel_items, [
             Pwb::Content.create!(),
             Pwb::Content.create!()
    ])
    assign(:content_area_cols, [
             Pwb::Content.create!(),
             Pwb::Content.create!()
    ])
  end

  it "renders index successfully" do
    render
    # assert_select "form[action=?][method=?]", welcome_path(@welcome), "post" do
    # end
  end


  # context 'when the product has a url' do
  #   it 'displays the url' do
  #     assign(:product, build(:product, url: 'http://example.com')

  #     render

  #     expect(rendered).to have_link 'Product', href: 'http://example.com'
  #   end
  # end

end
