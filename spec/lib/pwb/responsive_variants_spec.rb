# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ResponsiveVariants do
  describe "::WIDTHS" do
    it "defines standard responsive widths" do
      expect(described_class::WIDTHS).to eq([320, 640, 768, 1024, 1280, 1536, 1920])
    end
  end

  describe "::FORMATS" do
    it "defines format configurations with quality settings" do
      expect(described_class::FORMATS.keys).to match_array([:avif, :webp, :jpeg])

      expect(described_class::FORMATS[:webp][:format]).to eq(:webp)
      expect(described_class::FORMATS[:webp][:saver][:quality]).to eq(80)

      expect(described_class::FORMATS[:jpeg][:format]).to eq(:jpeg)
      expect(described_class::FORMATS[:jpeg][:saver][:quality]).to eq(85)
    end
  end

  describe "::SIZE_PRESETS" do
    it "defines named size presets" do
      expect(described_class::SIZE_PRESETS).to include(
        :hero, :card, :thumbnail, :content, :featured
      )
    end

    it "has valid sizes strings for each preset" do
      described_class::SIZE_PRESETS.each do |name, sizes|
        expect(sizes).to be_a(String), "Preset #{name} should be a string"
        expect(sizes).not_to be_empty, "Preset #{name} should not be empty"
      end
    end
  end

  describe ".widths_for" do
    it "returns all widths for large original images" do
      expect(described_class.widths_for(3000)).to eq(described_class::WIDTHS)
    end

    it "filters widths larger than original" do
      expect(described_class.widths_for(800)).to eq([320, 640, 768])
    end

    it "handles nil original width" do
      expect(described_class.widths_for(nil)).to eq(described_class::WIDTHS)
    end
  end

  describe ".formats_to_generate" do
    it "always includes webp and jpeg" do
      formats = described_class.formats_to_generate
      expect(formats).to include(:webp)
      expect(formats).to include(:jpeg)
    end

    it "webp comes before jpeg" do
      formats = described_class.formats_to_generate
      expect(formats.index(:webp)).to be < formats.index(:jpeg)
    end
  end

  describe ".sizes_for" do
    it "returns preset value for known preset symbol" do
      expect(described_class.sizes_for(:hero)).to eq(described_class::SIZE_PRESETS[:hero])
      expect(described_class.sizes_for(:card)).to eq(described_class::SIZE_PRESETS[:card])
    end

    it "returns the string directly for custom sizes" do
      custom = "(min-width: 600px) 300px, 100vw"
      expect(described_class.sizes_for(custom)).to eq(custom)
    end

    it "defaults to :card for unknown presets" do
      expect(described_class.sizes_for(:unknown_preset)).to eq(described_class::SIZE_PRESETS[:card])
    end
  end

  describe ".transformations_for" do
    it "returns hash with resize_to_limit and format options" do
      result = described_class.transformations_for(640, :webp)

      expect(result[:resize_to_limit]).to eq([640, nil])
      expect(result[:format]).to eq(:webp)
      expect(result[:saver]).to eq({ quality: 80 })
    end

    it "uses jpeg defaults for unknown format" do
      result = described_class.transformations_for(640, :unknown)

      expect(result[:format]).to eq(:jpeg)
      expect(result[:saver]).to eq({ quality: 85 })
    end
  end

  describe ".mime_type_for" do
    it "returns correct MIME types" do
      expect(described_class.mime_type_for(:webp)).to eq("image/webp")
      expect(described_class.mime_type_for(:jpeg)).to eq("image/jpeg")
      expect(described_class.mime_type_for(:avif)).to eq("image/avif")
    end
  end
end
