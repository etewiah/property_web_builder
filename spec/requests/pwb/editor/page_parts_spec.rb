require 'rails_helper'

module Pwb
  RSpec.describe "Editor::PageParts", type: :request do
    let(:admin_user) { FactoryBot.create(:pwb_user, :admin) }
    let!(:page_part) { FactoryBot.create(:pwb_page_part, page_part_key: "test_key", block_contents: { "title" => { "content" => "Original Title" } }) }

    before do
      sign_in :user, admin_user
    end

    describe "GET /editor/page_parts/:id" do
      it "returns the form partial" do
        get "/editor/page_parts/#{page_part.page_part_key}"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Original Title")
        expect(response.body).to include("form")
      end
    end

    describe "PATCH /editor/page_parts/:id" do
      it "updates the page part content" do
        patch "/editor/page_parts/#{page_part.page_part_key}", params: {
          page_part: {
            content: { "title" => "New Title" }
          }
        }
        
        expect(response).to have_http_status(:success)
        expect(page_part.reload.block_contents["title"]["content"]).to eq("New Title")
      end
    end
  end
end
