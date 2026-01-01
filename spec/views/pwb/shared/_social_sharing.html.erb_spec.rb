# frozen_string_literal: true

require "rails_helper"

RSpec.describe "pwb/shared/_social_sharing.html.erb", type: :view do
  let(:share_url) { "https://example.com/property/123" }
  let(:share_title) { "Beautiful 3BR Apartment" }

  describe "rendered output quality" do
    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title
      }
    end

    it "does not leak ERB comments or documentation to HTML" do
      expect(rendered).not_to include("Options:")
      expect(rendered).not_to include("(required)")
      expect(rendered).not_to include("Usage:")
      expect(rendered).not_to include(":fontawesome")
      expect(rendered).not_to include(":phosphor")
      expect(rendered).not_to include("%>")
    end

    it "does not contain empty class attributes" do
      expect(rendered).not_to match(/class=["']\s*["']/)
    end
  end

  describe "share URL parameters" do
    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title
      }
    end

    it "Facebook share link includes both URL and title (quote parameter)" do
      expect(rendered).to include("facebook.com/sharer/sharer.php")
      expect(rendered).to include("u=#{ERB::Util.url_encode(share_url)}")
      expect(rendered).to include("quote=#{ERB::Util.url_encode(share_title)}")
    end

    it "LinkedIn share link includes URL and title" do
      expect(rendered).to include("linkedin.com/shareArticle")
      expect(rendered).to include("mini=true")
      expect(rendered).to include("url=#{ERB::Util.url_encode(share_url)}")
      expect(rendered).to include("title=#{ERB::Util.url_encode(share_title)}")
    end

    it "Twitter share link includes both URL and title" do
      expect(rendered).to include("twitter.com/intent/tweet")
      expect(rendered).to include("url=#{ERB::Util.url_encode(share_url)}")
      expect(rendered).to include("text=#{ERB::Util.url_encode(share_title)}")
    end

    it "WhatsApp share link includes both title and URL in text" do
      expect(rendered).to include("wa.me/")
      encoded_both = ERB::Util.url_encode("#{share_title} #{share_url}")
      expect(rendered).to include("text=#{encoded_both}")
    end
  end

  describe "default style with brand icons" do
    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title
      }
    end

    it "uses SVG brand icons for social networks" do
      expect(rendered).to include("brand-icon-facebook")
      expect(rendered).to include("brand-icon-linkedin")
      expect(rendered).to include("brand-icon-x") # X (formerly Twitter)
      expect(rendered).to include("brand-icon-whatsapp")
    end

    it "wraps each icon in fixed-width container for consistent spacing" do
      # Each link should have w-8 h-8 for consistent clickable area
      expect(rendered.scan(/w-8 h-8/).count).to eq(4)
    end

    it "uses gap utility instead of space-x for consistent spacing" do
      expect(rendered).to include("gap-4")
      expect(rendered).not_to include("space-x-4")
    end

    it "opens links in new tab with security attributes" do
      expect(rendered).to include('target="_blank"')
      expect(rendered).to include('rel="noopener noreferrer"')
    end

    it "includes accessible title attributes for all networks" do
      expect(rendered).to include('title="Share on Facebook"')
      expect(rendered).to include('title="Share on LinkedIn"')
      expect(rendered).to include('title="Share on Twitter"')
      expect(rendered).to include('title="Share on WhatsApp"')
    end

    it "uses default centered layout with border" do
      expect(rendered).to include("justify-center")
      expect(rendered).to include("border-t")
    end
  end

  describe "bologna style with brand icons" do
    before do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        style: :bologna
      }
    end

    it "uses SVG brand icons" do
      expect(rendered).to include("brand-icon-facebook")
      expect(rendered).to include("brand-icon-linkedin")
      expect(rendered).to include("brand-icon-x") # X (formerly Twitter)
      expect(rendered).to include("brand-icon-whatsapp")
    end

    it "uses bologna container layout with gap" do
      expect(rendered).to include("flex items-center gap-3")
      expect(rendered).not_to include("border-t border-gray-100")
    end

    it "uses rounded button styling with consistent size" do
      expect(rendered).to include("rounded-full")
      expect(rendered.scan(/w-10 h-10/).count).to eq(4)
    end

    it "includes all share parameters in URLs" do
      expect(rendered).to include("quote=#{ERB::Util.url_encode(share_title)}")
      expect(rendered).to include("text=#{ERB::Util.url_encode(share_title)}")
    end
  end

  describe "custom networks" do
    it "renders only specified networks" do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        networks: [:facebook, :whatsapp]
      }

      expect(rendered).to include("brand-icon-facebook")
      expect(rendered).to include("brand-icon-whatsapp")
      expect(rendered).not_to include("brand-icon-linkedin")
      expect(rendered).not_to include("brand-icon-x")
    end

    it "renders single network" do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        networks: [:twitter]
      }

      expect(rendered).to include("brand-icon-x") # X (formerly Twitter)
      expect(rendered).not_to include("brand-icon-facebook")
    end

    it "maintains consistent container structure with fewer networks" do
      render partial: "pwb/shared/social_sharing", locals: {
        url: share_url,
        title: share_title,
        networks: [:facebook]
      }

      expect(rendered).to include("gap-4")
      expect(rendered).to include("w-8 h-8")
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

    it "properly encodes ampersand in title" do
      # & in title should be encoded as %26
      expect(rendered).to include("Apartment%20%26%20Terrace")
    end

    it "all networks receive properly encoded parameters" do
      encoded_url = ERB::Util.url_encode(share_url)
      encoded_title = ERB::Util.url_encode(share_title)

      # Facebook
      expect(rendered).to include("u=#{encoded_url}")
      expect(rendered).to include("quote=#{encoded_title}")

      # LinkedIn
      expect(rendered).to include("title=#{encoded_title}")

      # Twitter
      expect(rendered).to include("text=#{encoded_title}")

      # WhatsApp
      expect(rendered).to include(ERB::Util.url_encode("#{share_title} #{share_url}"))
    end
  end
end
