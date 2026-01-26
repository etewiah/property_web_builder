# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe "Editor::PageParts", type: :request do
    let(:website) { FactoryBot.create(:pwb_website, subdomain: 'editor-test') }
    let(:admin_user) { FactoryBot.create(:pwb_user, :admin, website: website) }
    let!(:page_part) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_part,
                          page_part_key: "test_key",
                          website: website,
                          block_contents: { "en" => { "blocks" => { "title" => { "content" => "Original Title" } } } })
      end
    end

    before do
      Pwb::Current.reset
      sign_in :user, admin_user
      allow(Pwb::Current).to receive(:website).and_return(website)
      # Set host to match tenant
      host! "#{website.subdomain}.test.host"
    end

    describe "GET /editor/page_parts/:id" do
      it "returns the form partial" do
        get "/editor/page_parts/#{page_part.page_part_key}"
        expect(response).to have_http_status(:success)
      end

      context "with editing_locale parameter" do
        it "passes the editing locale to the form" do
          get "/editor/page_parts/#{page_part.page_part_key}", params: { editing_locale: 'es' }
          expect(response).to have_http_status(:success)
        end
      end
    end

    describe "PATCH /editor/page_parts/:id" do
      it "updates the page part content" do
        patch "/editor/page_parts/#{page_part.page_part_key}", params: {
          page_part: {
            content: {
              "en" => {
                "blocks" => {
                  "title" => { "content" => "New Title" }
                }
              }
            }
          }
        }

        expect(response).to have_http_status(:success)
        expect(page_part.reload.block_contents.dig("en", "blocks", "title", "content")).to eq("New Title")
      end
    end

    describe "Auto-creation of PagePart records" do
      context "when page_part_key exists in PagePartLibrary" do
        let(:library_key) { 'about_us_services' }

        before do
          # Ensure no PagePart exists for this key
          Pwb::PagePart.where(website: website, page_part_key: library_key).destroy_all
        end

        it "auto-creates PagePart with fields from library definition" do
          expect {
            get "/editor/page_parts/#{library_key}"
          }.to change { Pwb::PagePart.where(website: website, page_part_key: library_key).count }.from(0).to(1)

          expect(response).to have_http_status(:success)

          created_part = Pwb::PagePart.find_by(website: website, page_part_key: library_key)
          expect(created_part).to be_present
          expect(created_part.website_id).to eq(website.id)
          expect(created_part.show_in_editor).to be true

          # Check that block_contents has the expected fields from PagePartLibrary
          # about_us_services has fields: title_a, content_a, title_b, content_b, title_c, content_c
          blocks = created_part.block_contents.dig('en', 'blocks')
          expect(blocks).to be_present
          expect(blocks.keys).to include('title_a', 'content_a', 'title_b', 'content_b', 'title_c', 'content_c')
        end

        it "returns a form with the auto-created fields" do
          get "/editor/page_parts/#{library_key}"

          expect(response).to have_http_status(:success)
          expect(response.body).to include('title_a')
          expect(response.body).to include('content_a')
        end

        it "can update the auto-created page part" do
          # First request creates the page part
          get "/editor/page_parts/#{library_key}"

          # Now update it
          patch "/editor/page_parts/#{library_key}", params: {
            page_part: {
              content: {
                "en" => {
                  "blocks" => {
                    "title_a" => { "content" => "Our Services" },
                    "content_a" => { "content" => "We provide excellent service." }
                  }
                }
              }
            }
          }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('success')

          created_part = Pwb::PagePart.find_by(website: website, page_part_key: library_key)
          expect(created_part.block_contents.dig('en', 'blocks', 'title_a', 'content')).to eq('Our Services')
        end
      end

      context "when page_part_key is NOT in PagePartLibrary" do
        let(:unknown_key) { 'completely_unknown_page_part_xyz' }

        before do
          # Ensure no PagePart exists for this key
          Pwb::PagePart.where(website: website, page_part_key: unknown_key).destroy_all
        end

        it "auto-creates PagePart with empty block_contents" do
          expect {
            get "/editor/page_parts/#{unknown_key}"
          }.to change { Pwb::PagePart.where(website: website, page_part_key: unknown_key).count }.from(0).to(1)

          expect(response).to have_http_status(:success)

          created_part = Pwb::PagePart.find_by(website: website, page_part_key: unknown_key)
          expect(created_part).to be_present
          expect(created_part.website_id).to eq(website.id)

          # block_contents should have empty blocks structure
          blocks = created_part.block_contents.dig('en', 'blocks')
          expect(blocks).to eq({})
        end
      end

      context "when page_part_key contains slashes" do
        let(:nested_key) { 'heroes/hero_centered' }

        before do
          Pwb::PagePart.where(website: website, page_part_key: nested_key).destroy_all
        end

        it "auto-creates PagePart for nested keys" do
          expect {
            get "/editor/page_parts/#{nested_key}"
          }.to change { Pwb::PagePart.where(website: website, page_part_key: nested_key).count }.from(0).to(1)

          expect(response).to have_http_status(:success)

          created_part = Pwb::PagePart.find_by(website: website, page_part_key: nested_key)
          expect(created_part).to be_present

          # heroes/hero_centered has fields like: pretitle, title, subtitle, etc.
          blocks = created_part.block_contents.dig('en', 'blocks')
          expect(blocks.keys).to include('title', 'subtitle')
        end
      end

      # Note: Testing "website context is missing" is difficult in request specs
      # because the subdomain resolver always falls back to Website.first.
      # The edge case is covered by the controller code returning page_part_not_found
      # when @current_website&.id is nil.
    end
  end
end
