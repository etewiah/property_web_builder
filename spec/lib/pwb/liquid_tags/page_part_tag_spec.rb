# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::LiquidTags::PagePartTag do
  let(:website) { create(:pwb_website, subdomain: 'page-part-tag-test') }
  let(:view) { double("view", render: "<rendered content>") }
  let(:context) do
    Liquid::Context.new({}, {}, {
      view: view,
      website: website,
      locale: :en
    })
  end

  before do
    Pwb::Current.reset
    # Ensure the tag is registered
    require Rails.root.join("app/lib/pwb/liquid_tags/page_part_tag")
  end

  describe "parsing" do
    it "parses page part key from quoted string" do
      tag = Liquid::Template.parse('{% page_part "heroes/hero_centered" %}')

      expect(tag).to be_present
    end

    it "parses page part key with single quotes" do
      tag = Liquid::Template.parse("{% page_part 'heroes/hero_centered' %}")

      expect(tag).to be_present
    end

    it "parses page part key with options" do
      tag = Liquid::Template.parse('{% page_part "cta/cta_banner", style: "primary" %}')

      expect(tag).to be_present
    end
  end

  describe "#render" do
    context "with existing page part in database" do
      let!(:page_part) do
        ActsAsTenant.with_tenant(website) do
          create(:pwb_page_part,
            website: website,
            page_part_key: "heroes/hero_centered",
            template: "<h1>{{ page_part.title.content }}</h1>",
            block_contents: {
              "en" => {
                "blocks" => {
                  "title" => { "content" => "Welcome" }
                }
              }
            }
          )
        end
      end

      it "renders page part content from database" do
        template = Liquid::Template.parse('{% page_part "heroes/hero_centered" %}')
        result = template.render(context)

        expect(result).to include("Welcome")
      end
    end

    context "without page part in database" do
      before do
        allow(Pwb::PagePartLibrary).to receive(:template_path)
          .with("nonexistent/part")
          .and_return(nil)
      end

      it "returns empty string when template not found" do
        template = Liquid::Template.parse('{% page_part "nonexistent/part" %}')
        result = template.render(context)

        expect(result).to eq("")
      end
    end

    context "without view context" do
      let(:context_without_view) do
        Liquid::Context.new({}, {}, { website: website })
      end

      it "returns empty string" do
        template = Liquid::Template.parse('{% page_part "heroes/hero_centered" %}')
        result = template.render(context_without_view)

        expect(result).to eq("")
      end
    end

    context "without website context" do
      let(:context_without_website) do
        Liquid::Context.new({}, {}, { view: view })
      end

      it "returns empty string" do
        template = Liquid::Template.parse('{% page_part "heroes/hero_centered" %}')
        result = template.render(context_without_website)

        expect(result).to eq("")
      end
    end
  end

  describe "tag registration" do
    it "is registered with Liquid" do
      expect(Liquid::Template.tags["page_part"]).to eq(described_class)
    end
  end
end
