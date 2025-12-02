require "rails_helper"

RSpec.describe "pwb/_footer.html.erb", type: :view do
  let(:website) { Pwb::Website.create!(company_display_name: "Test Site") }
  let(:agency) { Pwb::Agency.create!(company_name: "Test Agency", website: website) }
  let(:footer_content) { OpenStruct.new(raw: "Footer content") }

  before do
    assign(:current_website, website)
    assign(:current_agency, agency)
    assign(:footer_content, footer_content)
    allow(website).to receive(:links).and_return(Pwb::Link)
  end

  it "renders social_media_facebook link in footer if present" do
    website.links.create!(slug: "social_media_facebook", link_url: "https://facebook.com/test", visible: true, placement: :social_media, link_title: "Facebook")
    render partial: "pwb/_footer", locals: { current_website: website, current_agency: agency, footer_content: footer_content }
    expect(rendered).to include("https://facebook.com/test")
    expect(rendered).to include("fa-facebook")
  end

  it "does not render social_media_facebook link if not present" do
    render partial: "pwb/_footer", locals: { current_website: website, current_agency: agency, footer_content: footer_content }
    expect(rendered).not_to include("fa-facebook")
  end
end
