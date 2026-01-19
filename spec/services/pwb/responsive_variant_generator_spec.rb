# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ResponsiveVariantGenerator do
  let(:website) { create(:pwb_website) }
  let(:realty_asset) { create(:pwb_realty_asset, website: website) }
  let(:prop_photo) { create(:pwb_prop_photo, realty_asset: realty_asset) }

  describe "#valid?" do
    context "with no attachment" do
      before { prop_photo.image.purge if prop_photo.image.attached? }

      it "returns false" do
        generator = described_class.new(prop_photo.image)
        expect(generator.valid?).to be false
      end
    end

    context "with external URL photo" do
      let(:external_photo) do
        create(:pwb_prop_photo, realty_asset: realty_asset,
               external_url: "https://example.com/image.jpg")
      end

      it "returns false" do
        generator = described_class.new(external_photo.image)
        expect(generator.valid?).to be false
      end
    end

    context "with valid uploaded image", skip: "requires image fixture" do
      it "returns true" do
        # This test requires an actual image fixture
        # generator = described_class.new(photo_with_image.image)
        # expect(generator.valid?).to be true
      end
    end
  end

  describe "#build_srcset" do
    it "returns empty string for invalid attachment" do
      generator = described_class.new(prop_photo.image)
      expect(generator.build_srcset(:webp)).to eq("")
    end
  end

  describe "configuration integration" do
    it "uses ResponsiveVariants widths" do
      widths = Pwb::ResponsiveVariants.widths_for(1000)
      expect(widths).to include(320, 640, 768)
      expect(widths).not_to include(1024, 1280) # larger than 1000
    end

    it "uses ResponsiveVariants formats" do
      formats = Pwb::ResponsiveVariants.formats_to_generate
      expect(formats).to include(:webp, :jpeg)
    end
  end
end
