# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Testimonials", type: :request do
  let(:website) { create(:pwb_website) }
  
  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
  end

  describe "GET /api_public/v1/testimonials" do
    context "with visible testimonials" do
      before do
        create(:pwb_testimonial, website: website, visible: true, position: 1, author_name: "John Doe")
        create(:pwb_testimonial, website: website, visible: true, position: 2, author_name: "Jane Smith")
        create(:pwb_testimonial, website: website, visible: true, position: 3, author_name: "Bob Wilson")
        create(:pwb_testimonial, website: website, visible: false, position: 4, author_name: "Hidden Person")
      end

      it "returns only visible testimonials" do
        get "/api_public/v1/testimonials"
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json["testimonials"].length).to eq(3)
        expect(json["testimonials"].map { |t| t["author_name"] }).not_to include("Hidden Person")
      end

      it "returns testimonials ordered by position" do
        get "/api_public/v1/testimonials"
        
        json = JSON.parse(response.body)
        positions = json["testimonials"].map { |t| t["position"] }
        
        expect(positions).to eq([1, 2, 3])
      end

      it "includes all required fields" do
        get "/api_public/v1/testimonials"
        
        json = JSON.parse(response.body)
        testimonial = json["testimonials"].first
        
        expect(testimonial).to have_key("id")
        expect(testimonial).to have_key("quote")
        expect(testimonial).to have_key("author_name")
        expect(testimonial).to have_key("author_role")
        expect(testimonial).to have_key("author_photo")
        expect(testimonial).to have_key("rating")
        expect(testimonial).to have_key("position")
      end
    end

    context "with limit parameter" do
      before do
        create_list(:pwb_testimonial, 5, website: website, visible: true)
      end

      it "limits results when limit param is provided" do
        get "/api_public/v1/testimonials?limit=2"
        
        json = JSON.parse(response.body)
        expect(json["testimonials"].length).to eq(2)
      end
    end

    context "with featured_only parameter" do
      before do
        create(:pwb_testimonial, website: website, featured: true, visible: true, author_name: "Featured 1")
        create(:pwb_testimonial, website: website, featured: true, visible: true, author_name: "Featured 2")
        create(:pwb_testimonial, website: website, featured: false, visible: true, author_name: "Not Featured")
      end

      it "returns only featured when featured_only is true" do
        get "/api_public/v1/testimonials?featured_only=true"
        
        json = JSON.parse(response.body)
        expect(json["testimonials"].length).to eq(2)
        expect(json["testimonials"].map { |t| t["author_name"] }).to match_array(["Featured 1", "Featured 2"])
      end
    end

    context "with no testimonials" do
      it "returns empty array" do
        get "/api_public/v1/testimonials"
        
        json = JSON.parse(response.body)
        expect(json["testimonials"]).to eq([])
      end
    end
  end
end
