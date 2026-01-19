# frozen_string_literal: true

require "rails_helper"

module Pwb
  RSpec.describe ImagesHelper, type: :helper do
    describe "#make_media_responsive" do
      let(:trusted_url) { "https://pwb-seed-images.s3.amazonaws.com/test.jpg" }
      let(:original_html) { %(<img src="#{trusted_url}" alt="Test Image">) }

      it "replaces img tags with responsive pictures for trusted sources" do
        result = helper.make_media_responsive(original_html)

        expect(result).to include("<picture>")
        expect(result).to include("srcset")
        expect(result).to include("image/webp")
      end

      it "adds lazy loading to images" do
        result = helper.make_media_responsive(original_html)

        expect(result).to include('loading="lazy"')
      end

      it "adds async decoding to images" do
        result = helper.make_media_responsive(original_html)

        expect(result).to include('decoding="async"')
      end

      it "preserves alt text" do
        result = helper.make_media_responsive(original_html)

        expect(result).to include('alt="Test Image"')
      end

      it "preserves existing class attributes" do
        html = %(<img src="#{trusted_url}" class="my-class" alt="Test">)
        result = helper.make_media_responsive(html)

        expect(result).to include('class="my-class"')
      end

      it "returns original for non-JPEG images" do
        png_html = '<img src="https://pwb-seed-images.s3.amazonaws.com/test.png" alt="PNG">'
        result = helper.make_media_responsive(png_html)

        expect(result).not_to include("<picture>")
        expect(result).to include('loading="lazy"')
      end

      it "returns original for non-trusted sources" do
        untrusted_html = '<img src="https://example.com/image.jpg" alt="External">'
        result = helper.make_media_responsive(untrusted_html)

        expect(result).not_to include("<picture>")
        expect(result).to include('loading="lazy"')
      end

      it "skips images already in picture elements" do
        picture_html = '<picture><img src="https://pwb-seed-images.s3.amazonaws.com/test.jpg"></picture>'
        result = helper.make_media_responsive(picture_html)

        # Should have only one picture element (the original)
        expect(result.scan("<picture>").count).to eq(1)
      end

      it "returns blank content unchanged" do
        expect(helper.make_media_responsive("")).to eq("")
        expect(helper.make_media_responsive(nil)).to be_nil
      end

      it "accepts size preset option" do
        result = helper.make_media_responsive(original_html, sizes: :hero)
        sizes_value = Pwb::ResponsiveVariants.sizes_for(:hero)

        expect(result).to include("sizes=\"#{sizes_value}\"")
      end

      it "defaults to content size preset" do
        result = helper.make_media_responsive(original_html)
        sizes_value = Pwb::ResponsiveVariants.sizes_for(:content)

        expect(result).to include("sizes=\"#{sizes_value}\"")
      end
    end

    describe "#trusted_webp_source?" do
      it "returns true for seed images S3 bucket" do
        expect(helper.trusted_webp_source?("https://pwb-seed-images.s3.amazonaws.com/photo.jpg")).to be true
      end

      it "returns true for R2 seed assets" do
        expect(helper.trusted_webp_source?("https://seed-assets.propertywebbuilder.com/photo.jpg")).to be true
      end

      it "returns true for localhost" do
        expect(helper.trusted_webp_source?("http://localhost:3000/photo.jpg")).to be true
      end

      it "returns false for external URLs" do
        expect(helper.trusted_webp_source?("https://example.com/photo.jpg")).to be false
        expect(helper.trusted_webp_source?("https://rightmove.co.uk/photo.jpg")).to be false
      end

      it "returns false for blank URLs" do
        expect(helper.trusted_webp_source?("")).to be false
        expect(helper.trusted_webp_source?(nil)).to be false
      end
    end

    describe "#generate_responsive_srcset" do
      let(:website) { create(:pwb_website) }
      let(:realty_asset) { create(:pwb_realty_asset, website: website) }
      let(:photo) { create(:pwb_prop_photo, realty_asset: realty_asset) }

      context "without attached image" do
        it "returns empty string" do
          expect(helper.generate_responsive_srcset(photo, format: :webp)).to eq("")
        end
      end

      context "with external URL" do
        let(:external_photo) do
          create(:pwb_prop_photo, realty_asset: realty_asset,
                 external_url: "https://example.com/image.jpg")
        end

        it "returns empty string" do
          expect(helper.generate_responsive_srcset(external_photo, format: :webp)).to eq("")
        end
      end
    end
  end
end
