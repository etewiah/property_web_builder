require 'rails_helper'

module Pwb
  RSpec.describe "Editor::Images", type: :request do
    include ActionDispatch::TestProcess::FixtureFile

    let(:website) { FactoryBot.create(:pwb_website) }
    let(:user) { Pwb::User.create!(email: 'admin@example.com', password: 'password123', admin: true, website: website) }
    
    before do
      sign_in user
      Pwb::Current.website = website
    end

    describe "GET /editor/images" do
      it "returns a list of images" do
        # Create a content photo with attachment linked to the current website
        content = nil
        content_photo = nil
        
        ActsAsTenant.with_tenant(website) do
          content = FactoryBot.create(:pwb_content, website: website)
          content_photo = FactoryBot.create(:pwb_content_photo, content: content)
        end
        
        file_path = Rails.root.join("db/example_images/flat_balcony.jpg")
        
        # Attach image manually
        unless content_photo.image.attached?
          content_photo.image.attach(io: File.open(file_path), filename: 'flat_balcony.jpg', content_type: 'image/jpeg')
        end
        
        get "/en/editor/images"
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['images']).to be_an(Array)
        expect(json['images'].length).to be >= 1
        expect(json['images'].first['type']).to eq('content')
      end
    end

    describe "POST /editor/images" do
      it "uploads an image" do
        file = fixture_file_upload(Rails.root.join("db/example_images/flat_balcony.jpg"), 'image/jpeg')
        
        expect {
          post "/en/editor/images", params: { image: file }
        }.to change(Pwb::ContentPhoto, :count).by(1)
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['image']['filename']).to eq('flat_balcony.jpg')
      end

      it "returns error when no image provided" do
        post "/en/editor/images", params: {}
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
