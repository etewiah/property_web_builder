# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe "PagePartManager" do
    # Clean up tenant after each test
    after do
      ActsAsTenant.current_tenant = nil
    end

    context 'for website' do
      let!(:current_website) { FactoryBot.create(:pwb_website) }
      let(:page_part_key) { "footer_content_html" }
      let(:page_part_manager) { Pwb::PagePartManager.new page_part_key, current_website }
      let!(:page_part) do
        ActsAsTenant.with_tenant(current_website) do
          FactoryBot.create(:pwb_page_part, :footer_content_html_for_website, website: current_website)
        end
      end

      before do
        ActsAsTenant.current_tenant = current_website
      end

      it "creates content for website correctly" do
        # current_website = Pwb::Website.last
        # page_part_key = "footer_content_html"
        # page_part_manager = Pwb::PagePartManager.new page_part_key, current_website
        content_for_container = page_part_manager.find_or_create_content
        content_for_container_2 = page_part_manager.find_or_create_content

        expect(content_for_container).to eq(content_for_container_2)
        # expect( content_for_container.page_contents).to eq(current_website.page_contents)
        expect(current_website.contents).to include(content_for_container)
      end
      it 'seeds website content correctly' do
        locale = "en"
        seed_content = {
          "main_content" => "<p>We are proud to be registered with the national association of realtors.</p>"
        }
        # below would fail:
        #         "main_content":"<p>We are proud to be registered with the national association of realtors.</p>"

        page_part_manager.seed_container_block_content locale, seed_content

        expect(current_website.contents.find_by(page_part_key: page_part_key).raw).to include("We are proud to be registered with")
      end
    end
    context 'for pages' do
      let!(:page_website) { FactoryBot.create(:pwb_website) }
      let!(:contact_us_page) do
        ActsAsTenant.with_tenant(page_website) do
          FactoryBot.create(:page_with_content_html_page_part,
                             slug: "contact-us",
                             website: page_website)
        end
      end

      let(:page_part_key) { "content_html" }
      let(:page_part_manager) { Pwb::PagePartManager.new page_part_key, contact_us_page }

      before do
        ActsAsTenant.current_tenant = page_website
      end

      it "creates content for page correctly" do
        content_for_container = page_part_manager.find_or_create_content
        content_for_container_2 = page_part_manager.find_or_create_content

        expect(content_for_container).to eq(content_for_container_2)
        expect(contact_us_page.contents).to include(content_for_container)
      end

      it 'seeds page content correctly' do
        locale = "en"
        en_seed_content = {
          "main_content" => "<p>We are proud to be registered with the national association of realtors.</p>"
        }
        page_part_manager.seed_container_block_content locale, en_seed_content

        locale = "es"
        es_seed_content = {
          "main_content" => "<p>Estamos orgulloso.</p>"
        }
        page_part_manager.seed_container_block_content locale, es_seed_content

        expect(contact_us_page.contents.find_by(page_part_key: page_part_key).raw).to include("We are proud to be registered with")
        expect(contact_us_page.contents.find_by(page_part_key: page_part_key).raw_es).to include("Estamos orgulloso")
      end
    end

    describe '#rebuild_page_content' do
      let!(:current_website) { FactoryBot.create(:pwb_website) }

      before do
        ActsAsTenant.current_tenant = current_website
      end

      context 'when page_part has a template' do
        let!(:page_part) do
          ActsAsTenant.with_tenant(current_website) do
            FactoryBot.create(:pwb_page_part,
              page_part_key: "test_section",
              page_slug: "website",
              template: "<div class=\"test\">{{ page_part['title']['content'] }}</div>",
              editor_setup: {
                "tabTitleKey" => "test.title",
                "editorBlocks" => [
                  [{ "label" => "title", "isSingleLineText" => "true" }]
                ]
              },
              website: current_website)
          end
        end

        let(:page_part_manager) { Pwb::PagePartManager.new("test_section", current_website) }

        it 'renders Liquid template with block contents' do
          locale = "en"
          seed_content = { "title" => "Hello World" }

          page_part_manager.seed_container_block_content(locale, seed_content)

          content = current_website.contents.find_by(page_part_key: "test_section")
          expect(content.raw).to include("Hello World")
          expect(content.raw).to include('<div class="test">')
        end

        it 'handles multiple locales independently' do
          page_part_manager.seed_container_block_content("en", { "title" => "English Title" })
          page_part_manager.seed_container_block_content("es", { "title" => "Titulo Espanol" })

          content = current_website.contents.find_by(page_part_key: "test_section")
          expect(content.raw).to include("English Title")
          expect(content.raw_es).to include("Titulo Espanol")
        end
      end

      context 'when page_part has no template' do
        let!(:page_part_without_template) do
          ActsAsTenant.with_tenant(current_website) do
            FactoryBot.create(:pwb_page_part,
              page_part_key: "no_template_section",
              page_slug: "website",
              template: nil,
              editor_setup: {
                "tabTitleKey" => "test.title",
                "editorBlocks" => [
                  [{ "label" => "content", "isHtml" => "true" }]
                ]
              },
              website: current_website)
          end
        end

        let(:page_part_manager) { Pwb::PagePartManager.new("no_template_section", current_website) }

        it 'raises an error about missing template' do
          expect do
            page_part_manager.send(:rebuild_page_content, "en")
          end.to raise_error(RuntimeError, /page_part with valid template not available/)
        end
      end

      context 'when page_part has empty template' do
        let!(:page_part_empty_template) do
          ActsAsTenant.with_tenant(current_website) do
            FactoryBot.create(:pwb_page_part,
              page_part_key: "empty_template_section",
              page_slug: "website",
              template: "",
              editor_setup: {
                "tabTitleKey" => "test.title",
                "editorBlocks" => [
                  [{ "label" => "content", "isHtml" => "true" }]
                ]
              },
              website: current_website)
          end
        end

        let(:page_part_manager) { Pwb::PagePartManager.new("empty_template_section", current_website) }

        it 'renders empty content for empty template' do
          # Empty string templates parse fine but produce empty output
          seed_content = { "content" => "Some content" }
          page_part_manager.seed_container_block_content("en", seed_content)

          content = current_website.contents.find_by(page_part_key: "empty_template_section")
          # Empty template results in empty or nil raw content
          expect(content.raw.to_s).to eq("")
        end
      end

      context 'with complex Liquid templates' do
        let!(:page_part_with_conditionals) do
          ActsAsTenant.with_tenant(current_website) do
            FactoryBot.create(:pwb_page_part,
              page_part_key: "conditional_section",
              page_slug: "website",
              template: <<~LIQUID,
                <section>
                  {% if page_part['title']['content'] %}
                    <h2>{{ page_part['title']['content'] }}</h2>
                  {% endif %}
                  {% if page_part['subtitle']['content'] %}
                    <p>{{ page_part['subtitle']['content'] }}</p>
                  {% endif %}
                </section>
              LIQUID
              editor_setup: {
                "tabTitleKey" => "test.title",
                "editorBlocks" => [
                  [
                    { "label" => "title", "isSingleLineText" => "true" },
                    { "label" => "subtitle", "isSingleLineText" => "true" }
                  ]
                ]
              },
              website: current_website)
          end
        end

        let(:page_part_manager) { Pwb::PagePartManager.new("conditional_section", current_website) }

        it 'handles conditional rendering correctly' do
          seed_content = { "title" => "Main Title", "subtitle" => "" }
          page_part_manager.seed_container_block_content("en", seed_content)

          content = current_website.contents.find_by(page_part_key: "conditional_section")
          expect(content.raw).to include("Main Title")
          expect(content.raw).to include("<h2>")
        end

        it 'handles missing optional fields gracefully' do
          seed_content = { "title" => "Only Title" }
          page_part_manager.seed_container_block_content("en", seed_content)

          content = current_website.contents.find_by(page_part_key: "conditional_section")
          expect(content.raw).to include("Only Title")
        end
      end
    end

    describe '#update_page_part_content' do
      let!(:current_website) { FactoryBot.create(:pwb_website) }

      before do
        ActsAsTenant.current_tenant = current_website
      end

      let!(:page_part) do
        ActsAsTenant.with_tenant(current_website) do
          FactoryBot.create(:pwb_page_part,
            page_part_key: "update_test",
            page_slug: "website",
            template: "<div>{{ page_part['text']['content'] }}</div>",
            editor_setup: {
              "tabTitleKey" => "test.title",
              "editorBlocks" => [
                [{ "label" => "text", "isSingleLineText" => "true" }]
              ]
            },
            website: current_website)
        end
      end

      let(:page_part_manager) { Pwb::PagePartManager.new("update_test", current_website) }

      it 'returns both json block and html content' do
        fragment_block = { "blocks" => { "text" => { "content" => "Test content" } } }

        result = page_part_manager.update_page_part_content("en", fragment_block)

        expect(result).to have_key(:json_fragment_block)
        expect(result).to have_key(:fragment_html)
        expect(result[:fragment_html]).to include("Test content")
      end

      it 'saves block contents to page_part' do
        fragment_block = { "blocks" => { "text" => { "content" => "Saved content" } } }

        page_part_manager.update_page_part_content("en", fragment_block)

        page_part.reload
        expect(page_part.block_contents["en"]["blocks"]["text"]["content"]).to eq("Saved content")
      end
    end

    describe '#seed_container_block_content with URL-based images' do
      let!(:current_website) { FactoryBot.create(:pwb_website) }

      before do
        ActsAsTenant.current_tenant = current_website
      end

      let!(:page_part_with_image) do
        ActsAsTenant.with_tenant(current_website) do
          FactoryBot.create(:pwb_page_part,
            page_part_key: "testimonial_section",
            page_slug: "website",
            template: <<~LIQUID,
              <div class="testimonial">
                <img src="{{ page_part['avatar_image']['content'] }}" alt="avatar">
                <p>{{ page_part['name']['content'] }}</p>
              </div>
            LIQUID
            editor_setup: {
              "tabTitleKey" => "test.title",
              "editorBlocks" => [
                [
                  { "label" => "name", "isSingleLineText" => "true" },
                  { "label" => "avatar_image", "isImage" => "true" }
                ]
              ]
            },
            website: current_website)
        end
      end

      let(:page_part_manager) { Pwb::PagePartManager.new("testimonial_section", current_website) }

      it 'uses URL directly for HTTP image values' do
        # When image value is already a URL (like ui-avatars.com), use it directly
        en_seed_content = {
          "name" => "John Smith",
          "avatar_image" => "https://ui-avatars.com/api/?name=John+Smith&background=4f46e5&color=fff"
        }
        page_part_manager.seed_container_block_content("en", en_seed_content)

        content = current_website.contents.find_by(page_part_key: "testimonial_section")
        expect(content.raw).to include("John Smith")
        expect(content.raw).to include("https://ui-avatars.com/api/?name=John+Smith")
      end

      it 'handles different URL-based images per locale' do
        # English with English name avatar
        en_seed_content = {
          "name" => "Michael Chen",
          "avatar_image" => "https://ui-avatars.com/api/?name=Michael+Chen&background=059669&color=fff"
        }
        page_part_manager.seed_container_block_content("en", en_seed_content)

        # Spanish with Spanish name avatar
        es_seed_content = {
          "name" => "Carlos Rodriguez",
          "avatar_image" => "https://ui-avatars.com/api/?name=Carlos+Rodriguez&background=059669&color=fff"
        }
        page_part_manager.seed_container_block_content("es", es_seed_content)

        content = current_website.contents.find_by(page_part_key: "testimonial_section")
        # English content should have English name and avatar
        expect(content.raw).to include("Michael Chen")
        expect(content.raw).to include("name=Michael+Chen")

        # Spanish content should have Spanish name and avatar
        expect(content.raw_es).to include("Carlos Rodriguez")
        expect(content.raw_es).to include("name=Carlos+Rodriguez")
      end
    end
    
    describe 'responsive image integration' do
      let!(:current_website) { FactoryBot.create(:pwb_website) }
      let!(:page_part) do
        ActsAsTenant.with_tenant(current_website) do
          FactoryBot.create(:pwb_page_part,
            page_part_key: "hero",
            page_slug: "website",
            template: '<img src="{{ page_part[\'image\'][\'content\'] }}">',
            editor_setup: { 
              "editorBlocks" => [[{ "label" => "image", "isImage" => "true" }]] 
            },
            website: current_website)
        end
      end
      let(:page_part_manager) { Pwb::PagePartManager.new("hero", current_website) }

      before { ActsAsTenant.current_tenant = current_website }

      it 'optimizes images when rebuilding page content' do
        # Use a reliable test URL that the helper considers trusted
        seed_image_url = "https://pwb-seed-images.s3.amazonaws.com/example.jpg"
        
        page_part_manager.seed_container_block_content("en", {
          "image" => seed_image_url
        })

        content = current_website.contents.find_by(page_part_key: "hero")
        
        # Should be upgraded to picture tag
        expect(content.raw).to include("<picture>")
        expect(content.raw).to include("srcset")
        expect(content.raw).to include('type="image/webp"')
        expect(content.raw).to include(seed_image_url)
      end
    end
  end
end
