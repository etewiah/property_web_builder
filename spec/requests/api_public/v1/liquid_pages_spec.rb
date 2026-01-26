# frozen_string_literal: true

require 'rails_helper'

module ApiPublic
  module V1
    RSpec.describe "LiquidPages", type: :request do
      let(:website) { FactoryBot.create(:pwb_website, subdomain: 'liquid-test') }
      let!(:page) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page, slug: 'about-us', website: website)
        end
      end
      let!(:page_part) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_part,
                            page_part_key: "heroes/hero_centered",
                            website: website,
                            block_contents: {
                              "en" => {
                                "blocks" => {
                                  "title" => { "content" => "Welcome" },
                                  "subtitle" => { "content" => "Your journey starts here" }
                                }
                              },
                              "es" => {
                                "blocks" => {
                                  "title" => { "content" => "Bienvenido" },
                                  "subtitle" => { "content" => "Tu viaje comienza aquí" }
                                }
                              }
                            })
        end
      end
      let!(:page_content) do
        ActsAsTenant.with_tenant(website) do
          content = FactoryBot.create(:pwb_content,
                                      page_part_key: "heroes/hero_centered",
                                      website: website)
          FactoryBot.create(:pwb_page_content,
                            page: page,
                            content: content,
                            page_part_key: "heroes/hero_centered",
                            visible_on_page: true,
                            sort_order: 1,
                            website: website)
        end
      end

      before do
        Pwb::Current.reset
        allow(Pwb::Current).to receive(:website).and_return(website)
        host! "#{website.subdomain}.test.host"
      end

      describe "GET /api_public/v1/:locale/liquid_page/by_slug/:slug" do
        it "returns page data with liquid template and block_contents" do
          get "/api_public/v1/en/liquid_page/by_slug/about-us"

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json['slug']).to eq('about-us')
          expect(json['locale']).to eq('en')
          expect(json['page_contents']).to be_an(Array)
        end

        it "includes template and block_contents for each page part" do
          get "/api_public/v1/en/liquid_page/by_slug/about-us"

          json = JSON.parse(response.body)
          page_content = json['page_contents'].find { |pc| pc['page_part_key'] == 'heroes/hero_centered' }

          expect(page_content).to be_present
          expect(page_content['block_contents']).to be_present
          expect(page_content['block_contents']['blocks']['title']['content']).to eq('Welcome')
          expect(page_content['available_locales']).to include('en', 'es')
        end

        it "returns block_contents for the requested locale" do
          get "/api_public/v1/es/liquid_page/by_slug/about-us"

          json = JSON.parse(response.body)
          page_content = json['page_contents'].find { |pc| pc['page_part_key'] == 'heroes/hero_centered' }

          expect(page_content['block_contents']['blocks']['title']['content']).to eq('Bienvenido')
        end

        it "falls back to English if locale not available" do
          get "/api_public/v1/fr/liquid_page/by_slug/about-us"

          json = JSON.parse(response.body)
          page_content = json['page_contents'].find { |pc| pc['page_part_key'] == 'heroes/hero_centered' }

          # Should fall back to English since French is not available
          expect(page_content['block_contents']['blocks']['title']['content']).to eq('Welcome')
        end

        it "includes field_definitions from PagePartLibrary" do
          get "/api_public/v1/en/liquid_page/by_slug/about-us"

          json = JSON.parse(response.body)
          page_content = json['page_contents'].find { |pc| pc['page_part_key'] == 'heroes/hero_centered' }

          expect(page_content['field_definitions']).to be_an(Array)
          field_names = page_content['field_definitions'].map { |f| f['name'] }
          expect(field_names).to include('title', 'subtitle')
        end

        it "returns 404 for non-existent page" do
          get "/api_public/v1/en/liquid_page/by_slug/non-existent"

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_NOT_FOUND')
        end

        context "when page-specific PagePart exists alongside website-wide PagePart" do
          let!(:website_wide_page_part) do
            ActsAsTenant.with_tenant(website) do
              FactoryBot.create(:pwb_page_part,
                                page_part_key: "content_html",
                                page_slug: nil,
                                website: website,
                                block_contents: {
                                  "en" => {
                                    "blocks" => {
                                      "main_content" => { "content" => "Website-wide content" }
                                    }
                                  }
                                })
            end
          end

          let!(:page_specific_page_part) do
            ActsAsTenant.with_tenant(website) do
              FactoryBot.create(:pwb_page_part,
                                page_part_key: "content_html",
                                page_slug: "about-us",
                                website: website,
                                block_contents: {
                                  "en" => {
                                    "blocks" => {
                                      "main_content" => { "content" => "Page-specific about content" }
                                    }
                                  }
                                })
            end
          end

          let!(:content_html_page_content) do
            ActsAsTenant.with_tenant(website) do
              content = FactoryBot.create(:pwb_content,
                                          page_part_key: "content_html",
                                          key: "content_html_about_#{SecureRandom.hex(4)}",
                                          website: website)
              FactoryBot.create(:pwb_page_content,
                                page: page,
                                content: content,
                                page_part_key: "content_html",
                                visible_on_page: true,
                                sort_order: 3,
                                website: website)
            end
          end

          it "uses page-specific PagePart over website-wide" do
            get "/api_public/v1/en/liquid_page/by_slug/about-us"

            expect(response).to have_http_status(:success)
            json = JSON.parse(response.body)
            page_content = json['page_contents'].find { |pc| pc['page_part_key'] == 'content_html' }

            expect(page_content).to be_present
            # Should use page-specific content, not website-wide
            expect(page_content['block_contents']['blocks']['main_content']['content']).to eq('Page-specific about content')
          end
        end

        context "when PagePart doesn't exist" do
          let!(:orphan_page_content) do
            ActsAsTenant.with_tenant(website) do
              # Use a unique key for the content to avoid constraint violation
              content = FactoryBot.create(:pwb_content,
                                          page_part_key: "about_us_services",
                                          key: "about_us_services_content_#{SecureRandom.hex(4)}",
                                          website: website)
              FactoryBot.create(:pwb_page_content,
                                page: page,
                                content: content,
                                page_part_key: "about_us_services",
                                visible_on_page: true,
                                sort_order: 2,
                                website: website)
            end
          end

          before do
            # Ensure no PagePart exists for this key
            Pwb::PagePart.where(website: website, page_part_key: 'about_us_services').destroy_all
          end

          it "auto-creates PagePart with fields from library" do
            expect {
              get "/api_public/v1/en/liquid_page/by_slug/about-us"
            }.to change { Pwb::PagePart.where(website: website, page_part_key: 'about_us_services').count }.from(0).to(1)

            expect(response).to have_http_status(:success)
            json = JSON.parse(response.body)

            page_content = json['page_contents'].find { |pc| pc['page_part_key'] == 'about_us_services' }
            expect(page_content).to be_present
            expect(page_content['block_contents']).to be_present

            # about_us_services has fields: title_a, content_a, title_b, content_b, title_c, content_c
            blocks = page_content['block_contents']['blocks']
            expect(blocks.keys).to include('title_a', 'content_a')
          end
        end
      end
    end
  end
end
