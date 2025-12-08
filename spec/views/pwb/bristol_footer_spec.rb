require "rails_helper"

RSpec.describe "pwb/_footer", type: :view do
  let(:website) { FactoryBot.create(:pwb_website) }
  let(:agency) { website.agency } # Website factory creates an agency
  let(:footer_content) { OpenStruct.new(raw: "Footer content") }

  before do
    ActsAsTenant.current_tenant = website
    assign(:current_website, website)
    assign(:current_agency, agency)
    assign(:footer_content, footer_content)
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  # The default footer template uses the social_media_link helper which
  # checks the social_media hash on the passed object (@current_website)
  it "renders social_media_facebook link when the link exists" do
    website.update!(social_media: { "facebook" => "https://facebook.com/test" })

    render partial: "pwb/footer"

    expect(rendered).to include("https://facebook.com/test")
    expect(rendered).to include("fa-facebook")
  end

  it "renders social_media_twitter link when the link exists" do
    website.update!(social_media: { "twitter" => "https://twitter.com/test" })

    render partial: "pwb/footer"

    expect(rendered).to include("https://twitter.com/test")
    expect(rendered).to include("fa-twitter")
  end

  it "renders social_media_linkedin link when the link exists" do
    website.update!(social_media: { "linkedin" => "https://linkedin.com/test" })

    render partial: "pwb/footer"

    expect(rendered).to include("https://linkedin.com/test")
    expect(rendered).to include("fa-linkedin")
  end

  it "renders social_media_youtube link when the link exists" do
    website.update!(social_media: { "youtube" => "https://youtube.com/test" })

    render partial: "pwb/footer"

    expect(rendered).to include("https://youtube.com/test")
    expect(rendered).to include("fa-youtube")
  end

  it "renders social_media_pinterest link when the link exists" do
    website.update!(social_media: { "pinterest" => "https://pinterest.com/test" })

    render partial: "pwb/footer"

    expect(rendered).to include("https://pinterest.com/test")
    expect(rendered).to include("fa-pinterest")
  end
end
