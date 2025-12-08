# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::LiquidTags::FeaturedPropertiesTag do
  let(:website) { create(:pwb_website, subdomain: 'featured-props-test') }
  let(:view) { double("view") }
  let(:context) do
    Liquid::Context.new({}, {}, {
      view: view,
      website: website
    })
  end

  before do
    Pwb::Current.reset
    require Rails.root.join("app/lib/pwb/liquid_tags/featured_properties_tag")
  end

  describe "parsing" do
    it "parses without options" do
      tag = Liquid::Template.parse("{% featured_properties %}")

      expect(tag).to be_present
    end

    it "parses with limit option" do
      tag = Liquid::Template.parse("{% featured_properties limit: 6 %}")

      expect(tag).to be_present
    end

    it "parses with type option" do
      tag = Liquid::Template.parse('{% featured_properties type: "sale" %}')

      expect(tag).to be_present
    end

    it "parses with multiple options" do
      tag = Liquid::Template.parse('{% featured_properties limit: 4, type: "rent", style: "compact" %}')

      expect(tag).to be_present
    end
  end

  describe "#render" do
    let(:properties) do
      ActsAsTenant.with_tenant(website) do
        create_list(:pwb_prop, 3, website: website, visible: true)
      end
    end

    before do
      allow(view).to receive(:render).and_return("<property grid>")
    end

    context "with properties" do
      before do
        properties # create properties
      end

      it "renders property grid partial" do
        expect(view).to receive(:render).with(
          hash_including(partial: "pwb/components/property_grids/default")
        )

        template = Liquid::Template.parse("{% featured_properties %}")
        template.render(context)
      end

      it "passes properties to partial" do
        expect(view).to receive(:render).with(
          hash_including(locals: hash_including(:properties))
        )

        template = Liquid::Template.parse("{% featured_properties %}")
        template.render(context)
      end
    end

    context "without properties" do
      it "returns empty string" do
        template = Liquid::Template.parse("{% featured_properties %}")
        result = template.render(context)

        expect(result).to eq("")
      end
    end

    context "with style option" do
      before do
        properties
      end

      it "uses specified style partial" do
        expect(view).to receive(:render).with(
          hash_including(partial: "pwb/components/property_grids/compact")
        )

        template = Liquid::Template.parse('{% featured_properties style: "compact" %}')
        template.render(context)
      end

      it "falls back to default on missing template" do
        allow(view).to receive(:render)
          .with(hash_including(partial: "pwb/components/property_grids/custom"))
          .and_raise(ActionView::MissingTemplate.new([], "", [], false, ""))
        allow(view).to receive(:render)
          .with(hash_including(partial: "pwb/components/property_grids/default"))
          .and_return("<default grid>")

        template = Liquid::Template.parse('{% featured_properties style: "custom" %}')
        result = template.render(context)

        expect(result).to eq("<default grid>")
      end
    end

    context "without view" do
      let(:context_without_view) { Liquid::Context.new({}, {}, { website: website }) }

      it "returns empty string" do
        template = Liquid::Template.parse("{% featured_properties %}")
        result = template.render(context_without_view)

        expect(result).to eq("")
      end
    end
  end

  describe "valid types" do
    it "defines valid property types" do
      expect(described_class::VALID_TYPES).to include("sale", "rent", "all")
    end
  end

  describe "valid styles" do
    it "defines valid display styles" do
      expect(described_class::VALID_STYLES).to include("default", "compact", "card", "grid")
    end
  end

  describe "tag registration" do
    it "is registered with Liquid" do
      expect(Liquid::Template.tags["featured_properties"]).to eq(described_class)
    end
  end
end
