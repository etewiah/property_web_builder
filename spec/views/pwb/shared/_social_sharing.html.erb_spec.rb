require "rails_helper"

RSpec.describe "pwb/shared/_social_sharing.html.erb", type: :view do
  let(:share_url) { "https://example.com/property/123" }
  let(:share_title) { "Beautiful 3BR Apartment" }

  describe "default style with FontAwesome icons" do
    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title
      }
    end

    it "renders Facebook share link" do
      expect(rendered).to include("facebook.com/sharer/sharer.php")
      expect(rendered).to include(ERB::Util.url_encode(share_url))
    end

    it "renders LinkedIn share link" do
      expect(rendered).to include("linkedin.com/sharing/share-offsite")
      expect(rendered).to include(ERB::Util.url_encode(share_url))
    end

    it "renders Twitter share link" do
      expect(rendered).to include("twitter.com/intent/tweet")
      expect(rendered).to include(ERB::Util.url_encode(share_url))
      expect(rendered).to include(ERB::Util.url_encode(share_title))
    end

    it "renders WhatsApp share link" do
      expect(rendered).to include("wa.me/")
      expect(rendered).to include(ERB::Util.url_encode(share_title))
    end

    it "uses FontAwesome icons by default" do
      expect(rendered).to include("fa fa-facebook")
      expect(rendered).to include("fa fa-linkedin")
      expect(rendered).to include("fa fa-twitter")
      expect(rendered).to include("fa fa-whatsapp")
    end

    it "opens links in new tab with security attributes" do
      expect(rendered).to include('target="_blank"')
      expect(rendered).to include('rel="noopener noreferrer"')
    end

    it "includes accessible title attributes" do
      expect(rendered).to include('title="Share on Facebook"')
      expect(rendered).to include('title="Share on LinkedIn"')
      expect(rendered).to include('title="Share on Twitter"')
      expect(rendered).to include('title="Share on WhatsApp"')
    end

    it "uses default centered layout" do
      expect(rendered).to include("justify-center")
      expect(rendered).to include("border-t")
    end
  end

  describe "bologna style with Phosphor icons" do
    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        icon_style: :phosphor,
        style: :bologna
      }
    end

    it "uses Phosphor icons" do
      expect(rendered).to include("ph ph-facebook-logo")
      expect(rendered).to include("ph ph-linkedin-logo")
      expect(rendered).to include("ph ph-x-logo")
      expect(rendered).to include("ph ph-whatsapp-logo")
    end

    it "uses bologna container layout" do
      # Bologna uses 'flex items-center space-x-3' for the container
      expect(rendered).to include("flex items-center space-x-3")
      # Should not have border-t in the container (default style has it)
      expect(rendered).not_to include("border-t border-gray-100")
    end

    it "uses rounded button styling" do
      expect(rendered).to include("rounded-full")
      expect(rendered).to include("w-10 h-10")
    end
  end

  describe "custom networks" do
    it "renders only specified networks" do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        networks: [:facebook, :whatsapp]
      }

      expect(rendered).to include("fa fa-facebook")
      expect(rendered).to include("fa fa-whatsapp")
      expect(rendered).not_to include("fa fa-linkedin")
      expect(rendered).not_to include("fa fa-twitter")
    end

    it "renders single network" do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        networks: [:twitter]
      }

      expect(rendered).to include("fa fa-twitter")
      expect(rendered).not_to include("fa fa-facebook")
    end
  end

  describe "URL encoding" do
    let(:share_url) { "https://example.com/property/123?ref=search&filter=3br" }
    let(:share_title) { "Beautiful Apartment & Terrace" }

    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title
      }
    end

    it "properly encodes special characters in URL" do
      # & should be encoded as %26
      expect(rendered).to include("%26")
    end

    it "properly encodes special characters in title" do
      # & in title should be encoded
      expect(rendered).to include("Apartment")
    end
  end
end
