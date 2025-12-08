# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::LiquidTags::ContactFormTag do
  let(:website) { create(:pwb_website, subdomain: 'liquid-tag-test') }
  let(:view) { double("view") }
  let(:context) do
    Liquid::Context.new({}, {}, {
      view: view,
      website: website
    })
  end

  before do
    Pwb::Current.reset
    require Rails.root.join("app/lib/pwb/liquid_tags/contact_form_tag")
  end

  describe "parsing" do
    it "parses without options" do
      tag = Liquid::Template.parse("{% contact_form %}")

      expect(tag).to be_present
    end

    it "parses with style option" do
      tag = Liquid::Template.parse('{% contact_form style: "compact" %}')

      expect(tag).to be_present
    end

    it "parses with property_id option" do
      tag = Liquid::Template.parse("{% contact_form property_id: 123 %}")

      expect(tag).to be_present
    end

    it "parses with multiple options" do
      tag = Liquid::Template.parse('{% contact_form style: "inline", property_id: 123, show_phone: "false" %}')

      expect(tag).to be_present
    end
  end

  describe "#render" do
    before do
      allow(view).to receive(:render).and_return("<contact form>")
    end

    it "renders default contact form partial" do
      expect(view).to receive(:render).with(
        hash_including(partial: "pwb/components/contact_forms/default")
      )

      template = Liquid::Template.parse("{% contact_form %}")
      template.render(context)
    end

    context "with style option" do
      it "renders specified style partial" do
        expect(view).to receive(:render).with(
          hash_including(partial: "pwb/components/contact_forms/compact")
        )

        template = Liquid::Template.parse('{% contact_form style: "compact" %}')
        template.render(context)
      end

      it "falls back to default on missing template" do
        allow(view).to receive(:render)
          .with(hash_including(partial: "pwb/components/contact_forms/custom"))
          .and_raise(ActionView::MissingTemplate.new([], "", [], false, ""))
        allow(view).to receive(:render)
          .with(hash_including(partial: "pwb/components/contact_forms/default"))
          .and_return("<default form>")

        template = Liquid::Template.parse('{% contact_form style: "custom" %}')
        result = template.render(context)

        expect(result).to eq("<default form>")
      end
    end

    it "passes website to partial" do
      expect(view).to receive(:render).with(
        hash_including(locals: hash_including(website: website))
      )

      template = Liquid::Template.parse("{% contact_form %}")
      template.render(context)
    end

    it "passes property_id to partial" do
      expect(view).to receive(:render).with(
        hash_including(locals: hash_including(property_id: 123))
      )

      template = Liquid::Template.parse("{% contact_form property_id: 123 %}")
      template.render(context)
    end

    it "passes show_phone option to partial" do
      expect(view).to receive(:render).with(
        hash_including(locals: hash_including(show_phone: false))
      )

      template = Liquid::Template.parse('{% contact_form show_phone: "false" %}')
      template.render(context)
    end

    it "passes show_message option to partial" do
      expect(view).to receive(:render).with(
        hash_including(locals: hash_including(show_message: false))
      )

      template = Liquid::Template.parse('{% contact_form show_message: "false" %}')
      template.render(context)
    end

    it "passes custom button_text to partial" do
      expect(view).to receive(:render).with(
        hash_including(locals: hash_including(button_text: "Submit"))
      )

      template = Liquid::Template.parse('{% contact_form button_text: "Submit" %}')
      template.render(context)
    end

    it "passes custom success_message to partial" do
      expect(view).to receive(:render).with(
        hash_including(locals: hash_including(success_message: "Thanks!"))
      )

      template = Liquid::Template.parse('{% contact_form success_message: "Thanks!" %}')
      template.render(context)
    end

    context "without view" do
      let(:context_without_view) { Liquid::Context.new({}, {}, { website: website }) }

      it "returns empty string" do
        template = Liquid::Template.parse("{% contact_form %}")
        result = template.render(context_without_view)

        expect(result).to eq("")
      end
    end
  end

  describe "valid styles" do
    it "defines valid form styles" do
      expect(described_class::VALID_STYLES).to include("default", "compact", "inline", "sidebar")
    end
  end

  describe "tag registration" do
    it "is registered with Liquid" do
      expect(Liquid::Template.tags["contact_form"]).to eq(described_class)
    end
  end
end
