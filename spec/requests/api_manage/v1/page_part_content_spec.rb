# frozen_string_literal: true

require 'rails_helper'

module ApiManage
  module V1
    RSpec.describe "PagePartContent", type: :request do
      let(:website) { FactoryBot.create(:pwb_website, subdomain: 'content-test') }
      let!(:page) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page, slug: 'contact-us', website: website)
        end
      end
      let!(:page_part) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_part,
                            page_part_key: "content_html",
                            page_slug: "contact-us",
                            website: website,
                            block_contents: {
                              'en' => {
                                'blocks' => {
                                  'main_content' => { 'content' => 'Original content' }
                                }
                              }
                            })
        end
      end
      let!(:page_content) do
        ActsAsTenant.with_tenant(website) do
          content = FactoryBot.create(:pwb_content,
                                      page_part_key: "content_html",
                                      website: website,
                                      key: "content_html_contact")
          FactoryBot.create(:pwb_page_content,
                            page: page,
                            content: content,
                            page_part_key: "content_html",
                            visible_on_page: true,
                            website: website)
        end
      end

      before do
        Pwb::Current.reset
        allow(Pwb::Current).to receive(:website).and_return(website)
        host! "#{website.subdomain}.test.host"
      end

      describe "GET /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key" do
        it "returns page part details" do
          get "/api_manage/v1/en/pages/contact-us/page_parts/content_html", as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json['page_slug']).to eq('contact-us')
          expect(json['page_part_key']).to eq('content_html')
          expect(json['locale']).to eq('en')
          expect(json['block_contents']).to be_present
        end

        it "returns 404 for non-existent page" do
          get "/api_manage/v1/en/pages/non-existent/page_parts/content_html", as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_NOT_FOUND')
        end
      end

      describe "PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key" do
        it "updates content with provided rendered_html" do
          patch "/api_manage/v1/en/pages/contact-us/page_parts/content_html",
                params: {
                  block_contents: {
                    main_content: { content: "Updated content" }
                  },
                  rendered_html: "<section class='pwb-section'>Updated content</section>"
                },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json['page_slug']).to eq('contact-us')
          expect(json['page_part_key']).to eq('content_html')
          expect(json['message']).to eq('Page part content updated successfully')

          # Verify block_contents was updated
          page_part.reload
          expect(page_part.block_contents.dig('en', 'blocks', 'main_content', 'content')).to eq('Updated content')
        end

        it "requires rendered_html parameter" do
          patch "/api_manage/v1/en/pages/contact-us/page_parts/content_html",
                params: {
                  block_contents: {
                    main_content: { content: "Updated content" }
                  }
                },
                as: :json

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Missing parameter')
          expect(json['message']).to include("'rendered_html' is missing")
        end

        it "allows skipping rendered_html when regenerate is true" do
          patch "/api_manage/v1/en/pages/contact-us/page_parts/content_html",
                params: {
                  block_contents: {
                    main_content: { content: "Regenerated content" }
                  },
                  regenerate: true
                },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Page part content updated successfully')
        end

        it "accepts string 'true' for regenerate parameter" do
          patch "/api_manage/v1/en/pages/contact-us/page_parts/content_html",
                params: {
                  block_contents: {
                    main_content: { content: "Regenerated content" }
                  },
                  regenerate: "true"
                },
                as: :json

          expect(response).to have_http_status(:success)
        end

        it "returns 404 for non-existent page" do
          patch "/api_manage/v1/en/pages/non-existent/page_parts/content_html",
                params: {
                  rendered_html: "<section>Test</section>"
                },
                as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_NOT_FOUND')
        end

        it "auto-creates page part if it doesn't exist" do
          # Delete existing page_part
          page_part.destroy

          patch "/api_manage/v1/en/pages/contact-us/page_parts/new_content_part",
                params: {
                  block_contents: {
                    main_content: { content: "New content" }
                  },
                  rendered_html: "<section>New content</section>"
                },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json['page_part_key']).to eq('new_content_part')

          # Verify new page part was created
          new_part = Pwb::PagePart.find_by(
            website_id: website.id,
            page_part_key: 'new_content_part',
            page_slug: 'contact-us'
          )
          expect(new_part).to be_present
        end

        it "handles nested blocks format" do
          patch "/api_manage/v1/en/pages/contact-us/page_parts/content_html",
                params: {
                  block_contents: {
                    blocks: {
                      main_content: { content: "Nested format" }
                    }
                  },
                  rendered_html: "<section>Nested format</section>"
                },
                as: :json

          expect(response).to have_http_status(:success)

          page_part.reload
          expect(page_part.block_contents.dig('en', 'blocks', 'main_content', 'content')).to eq('Nested format')
        end
      end
    end
  end
end
