# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::LiquidTags::PropertyCardTag do
  let(:website) { create(:pwb_website, subdomain: 'property-card-test') }
  let(:view) { double("view") }
  let(:context) do
    Liquid::Context.new({}, {}, {
      view: view,
      website: website
    })
  end

  before do
    Pwb::Current.reset
    require Rails.root.join("app/lib/pwb/liquid_tags/property_card_tag")
  end

  describe "parsing" do
    it "parses with property id" do
      tag = Liquid::Template.parse("{% property_card 123 %}")

      expect(tag).to be_present
    end

    it "parses with variable property id" do
      tag = Liquid::Template.parse("{% property_card property_id %}")

      expect(tag).to be_present
    end

    it "parses with style option" do
      tag = Liquid::Template.parse('{% property_card 123, style: "compact" %}')

      expect(tag).to be_present
    end

    it "raises syntax error without property id" do
      expect {
        Liquid::Template.parse("{% property_card %}")
      }.to raise_error(Liquid::SyntaxError)
    end
  end

  describe "#render" do
    let(:property) do
      ActsAsTenant.with_tenant(website) do
        create(:pwb_prop, website: website)
      end
    end

    before do
      allow(view).to receive(:render).and_return("<property card>")
    end

    context "with valid property id" do
      it "renders property card partial" do
        expect(view).to receive(:render).with(
          hash_including(partial: "pwb/components/property_cards/default")
        )

        template = Liquid::Template.parse("{% property_card #{property.id} %}")
        template.render(context)
      end

      it "passes property to partial" do
        expect(view).to receive(:render).with(
          hash_including(locals: hash_including(property: property))
        )

        template = Liquid::Template.parse("{% property_card #{property.id} %}")
        template.render(context)
      end
    end

    context "with property reference" do
      let(:property) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_prop, website: website, reference: "PROP-001")
        end
      end

      it "finds property by reference" do
        expect(view).to receive(:render).with(
          hash_including(locals: hash_including(property: property))
        )

        template = Liquid::Template.parse("{% property_card PROP-001 %}")
        template.render(context)
      end
    end

    context "with variable property id" do
      it "resolves property id from context" do
        context["my_property_id"] = property.id

        expect(view).to receive(:render).with(
          hash_including(locals: hash_including(property: property))
        )

        template = Liquid::Template.parse("{% property_card my_property_id %}")
        template.render(context)
      end
    end

    context "with style option" do
      it "uses specified style partial" do
        expect(view).to receive(:render).with(
          hash_including(partial: "pwb/components/property_cards/compact")
        )

        template = Liquid::Template.parse("{% property_card #{property.id}, style: \"compact\" %}")
        template.render(context)
      end

      it "falls back to default on missing template" do
        allow(view).to receive(:render)
          .with(hash_including(partial: "pwb/components/property_cards/custom"))
          .and_raise(ActionView::MissingTemplate.new([], "", [], false, ""))
        allow(view).to receive(:render)
          .with(hash_including(partial: "pwb/components/property_cards/default"))
          .and_return("<default card>")

        template = Liquid::Template.parse("{% property_card #{property.id}, style: \"custom\" %}")
        result = template.render(context)

        expect(result).to eq("<default card>")
      end
    end

    context "with invalid property id" do
      it "returns empty string" do
        template = Liquid::Template.parse("{% property_card 99999 %}")
        result = template.render(context)

        expect(result).to eq("")
      end
    end

    context "with property from different website" do
      let(:other_website) { create(:pwb_website, subdomain: 'other-property-card-test') }
      let(:other_property) do
        ActsAsTenant.with_tenant(other_website) do
          create(:pwb_prop, website: other_website)
        end
      end

      it "returns empty string for cross-tenant property" do
        template = Liquid::Template.parse("{% property_card #{other_property.id} %}")
        result = template.render(context)

        expect(result).to eq("")
      end
    end

    context "without view" do
      let(:context_without_view) { Liquid::Context.new({}, {}, { website: website }) }

      it "returns empty string" do
        template = Liquid::Template.parse("{% property_card 123 %}")
        result = template.render(context_without_view)

        expect(result).to eq("")
      end
    end

    context "without property id" do
      let(:context_with_nil) do
        ctx = Liquid::Context.new({}, {}, { view: view, website: website })
        ctx["property_id"] = nil
        ctx
      end

      it "returns empty string" do
        template = Liquid::Template.parse("{% property_card property_id %}")
        result = template.render(context_with_nil)

        expect(result).to eq("")
      end
    end
  end

  describe "tag registration" do
    it "is registered with Liquid" do
      expect(Liquid::Template.tags["property_card"]).to eq(described_class)
    end
  end
end
