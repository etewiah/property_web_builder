require 'rails_helper'

module Pwb
  describe ResponsiveContentMigrationService do
    let(:service) { described_class.new }
    let(:html_with_image) { '<img src="https://pwb-seed-images.s3.amazonaws.com/test.jpg" alt="Test">' }
    
    describe "#run" do
      it "updates content with responsive images" do
        content = Pwb::Content.create!(
          key: "test_content",
          tag: "test",
          translations: { "en" => html_with_image }
        )

        result = service.run
        content.reload

        expect(result[:updated_count]).to eq(1)
        expect(content.translations["en"]).to include("<picture>")
        expect(content.translations["en"]).to include("srcset")
      end

      it "does not update content that is already responsive" do
        responsive_html = '<picture><source srcset="..."><img src="..." loading="lazy"></picture>'
        # Normalize HTML to match what the service produces (Nokogiri parsing)
        normalized_html = Nokogiri::HTML::DocumentFragment.parse(responsive_html).to_html
        
        content = Pwb::Content.create!(
          key: "already_responsive",
          tag: "test",
          translations: { "en" => normalized_html }
        )

        result = service.run
        
        expect(result[:updated_count]).to eq(0)
      end
    end
  end
end
