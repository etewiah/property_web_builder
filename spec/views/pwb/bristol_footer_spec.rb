require "rails_helper"

RSpec.describe "pwb/_footer", type: :view do
  let(:website) { FactoryBot.create(:pwb_website) }
  let(:agency) { FactoryBot.create(:pwb_agency, website: website) }
  let(:footer_content) { OpenStruct.new(raw: "Footer content") }

  before do
    assign(:current_website, website)
    assign(:current_agency, agency)
    assign(:footer_content, footer_content)
    
    # Add the theme view path so it finds the bristol footer
    controller.prepend_view_path(File.join(Rails.root, "app/themes/bristol/views"))
  end

  it "renders social_media_facebook link when the link exists" do
    # Create the link
    website.links.create!(
      slug: "social_media_facebook", 
      link_url: "https://facebook.com/test", 
      visible: true, 
      placement: :social_media, 
      link_title: "Facebook"
    )

    # We render the partial "pwb/footer". 
    # Because we prepended the view path, it should find the one in app/themes/bristol/views/pwb/_footer.html.erb
    render partial: "pwb/footer"

    expect(rendered).to include("https://facebook.com/test")
    expect(rendered).to include("fa-facebook")
  end

  it "renders social_media_twitter link when the link exists" do
    website.links.create!(
      slug: "social_media_twitter", 
      link_url: "https://twitter.com/test", 
      visible: true, 
      placement: :social_media, 
      link_title: "Twitter"
    )
    render partial: "pwb/footer"
    expect(rendered).to include("https://twitter.com/test")
    expect(rendered).to include("fa-twitter")
  end

  it "renders social_media_linkedin link when the link exists" do
    website.links.create!(
      slug: "social_media_linkedin", 
      link_url: "https://linkedin.com/test", 
      visible: true, 
      placement: :social_media, 
      link_title: "LinkedIn"
    )
    render partial: "pwb/footer"
    expect(rendered).to include("https://linkedin.com/test")
    expect(rendered).to include("fa-linkedin")
  end

  it "renders social_media_youtube link when the link exists" do
    website.links.create!(
      slug: "social_media_youtube", 
      link_url: "https://youtube.com/test", 
      visible: true, 
      placement: :social_media, 
      link_title: "YouTube"
    )
    render partial: "pwb/footer"
    expect(rendered).to include("https://youtube.com/test")
    expect(rendered).to include("fa-youtube")
  end

  it "renders social_media_pinterest link when the link exists" do
    website.links.create!(
      slug: "social_media_pinterest", 
      link_url: "https://pinterest.com/test", 
      visible: true, 
      placement: :social_media, 
      link_title: "Pinterest"
    )
    render partial: "pwb/footer"
    expect(rendered).to include("https://pinterest.com/test")
    expect(rendered).to include("fa-pinterest")
  end
end
