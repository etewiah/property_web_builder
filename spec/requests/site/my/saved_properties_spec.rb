# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pwb::Site::My::SavedProperties", type: :request do
  let(:website) { create(:website) }

  before do
    allow_any_instance_of(Pwb::ApplicationController).to receive(:current_website).and_return(website)
  end

  describe "POST /my/favorites (create)" do
    context "with internal property" do
      let(:property_data) do
        {
          title: "Beautiful Villa",
          price: { cents: 50_000_000, currency_iso: "EUR" },
          currency: "EUR",
          bedrooms: 3,
          bathrooms: 2,
          city: "Marbella",
          listing_type: "sale",
          images: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
        }
      end

      it "creates a saved property for internal listings" do
        expect {
          post my_favorites_path, params: {
            saved_property: {
              email: "user@example.com",
              provider: "internal",
              external_reference: "PROP123",
              property_data: property_data.to_json,
              notes: "Great property!"
            }
          }
        }.to change(Pwb::SavedProperty, :count).by(1)

        saved = Pwb::SavedProperty.last
        expect(saved.email).to eq("user@example.com")
        expect(saved.provider).to eq("internal")
        expect(saved.external_reference).to eq("PROP123")
        expect(saved.title).to eq("Beautiful Villa")
        expect(saved.notes).to eq("Great property!")
      end

      it "redirects to favorites page with token" do
        post my_favorites_path, params: {
          saved_property: {
            email: "user@example.com",
            provider: "internal",
            external_reference: "PROP123",
            property_data: property_data.to_json
          }
        }

        saved = Pwb::SavedProperty.last
        expect(response).to redirect_to(my_favorites_path(token: saved.manage_token))
      end

      it "does not require external feed to be configured" do
        # Ensure no external feed is configured
        expect(website.external_feed.configured?).to be false

        post my_favorites_path, params: {
          saved_property: {
            email: "user@example.com",
            provider: "internal",
            external_reference: "PROP123",
            property_data: property_data.to_json
          }
        }

        expect(response).to redirect_to(my_favorites_path(token: Pwb::SavedProperty.last.manage_token))
      end
    end

    context "with external property" do
      before do
        # External properties require feed to be configured
        website.update!(external_feed_enabled: false)
      end

      it "redirects with alert when feed not configured" do
        post my_favorites_path, params: {
          saved_property: {
            email: "user@example.com",
            provider: "resales_online",
            external_reference: "EXT123"
          }
        }

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to eq("Favorites are not available")
      end
    end
  end

  describe "GET /my/favorites (index)" do
    context "with valid token" do
      let!(:saved_property) do
        create(:pwb_saved_property,
               website: website,
               email: "user@example.com",
               provider: "internal",
               external_reference: "apartment-marbella-prop123")
      end

      it "displays favorites page" do
        get my_favorites_path(token: saved_property.manage_token)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("My Favorite Properties")
        expect(response.body).to include("user@example.com")
      end

      it "displays property details" do
        get my_favorites_path(token: saved_property.manage_token)

        expect(response.body).to include(saved_property.title)
      end

      it "generates correct View Property link for internal sale properties" do
        get my_favorites_path(token: saved_property.manage_token)

        # Should link to prop_show_for_sale_path with the slug
        expect(response.body).to include("/properties/for-sale/apartment-marbella-prop123/")
      end

      it "generates correct View Property link for internal rental properties" do
        saved_property.update!(property_data: saved_property.property_data.merge("listing_type" => "rental"))

        get my_favorites_path(token: saved_property.manage_token)

        # Should link to prop_show_for_rent_path with the slug
        expect(response.body).to include("/properties/for-rent/apartment-marbella-prop123/")
      end
    end

    context "with external provider" do
      let!(:external_saved) do
        create(:pwb_saved_property,
               website: website,
               email: "user@example.com",
               provider: "resales_online",
               external_reference: "EXT123")
      end

      it "generates correct View Property link for external properties" do
        get my_favorites_path(token: external_saved.manage_token)

        # Should link to external_listing_path
        expect(response.body).to include("/external_listings/EXT123")
      end
    end

    context "with invalid token" do
      it "shows no favorites page" do
        get my_favorites_path(token: "invalid-token")

        expect(response).to have_http_status(:success)
        # Should render no_favorites template
      end
    end
  end

  describe "DELETE /my/favorites/:id" do
    let!(:saved_property) do
      create(:pwb_saved_property,
             website: website,
             email: "user@example.com",
             provider: "internal")
    end

    it "removes the saved property" do
      expect {
        delete my_favorite_path(id: saved_property.id, token: saved_property.manage_token)
      }.to change(Pwb::SavedProperty, :count).by(-1)
    end

    it "redirects appropriately after deletion" do
      delete my_favorite_path(id: saved_property.id, token: saved_property.manage_token)

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to include("removed")
    end
  end
end

RSpec.describe Pwb::SavedProperty, "internal property handling" do
  let(:website) { create(:pwb_website) }

  describe "#price with Money hash format" do
    it "extracts price from Money-like hash" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: {
                      title: "Test",
                      price: { cents: 27_500_000, currency_iso: "USD" }
                    })

      expect(saved.price).to eq(275_000)
    end

    it "handles plain integer price" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: {
                      title: "Test",
                      price: 450_000
                    })

      expect(saved.price).to eq(450_000)
    end

    it "returns nil when no price" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: { title: "Test" })

      expect(saved.price).to be_nil
    end
  end

  describe "#price_formatted with Money hash format" do
    it "formats price with currency from Money hash" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: {
                      title: "Test",
                      price: { cents: 27_500_000, currency_iso: "USD" }
                    })

      expect(saved.price_formatted).to eq("USD 275,000")
    end

    it "formats plain price with currency field" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: {
                      title: "Test",
                      price: 450_000,
                      currency: "EUR"
                    })

      expect(saved.price_formatted).to eq("EUR 450,000")
    end
  end

  describe "#main_image" do
    it "returns first image from images array" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: {
                      title: "Test",
                      images: ["https://example.com/img1.jpg", "https://example.com/img2.jpg"]
                    })

      expect(saved.main_image).to eq("https://example.com/img1.jpg")
    end

    it "returns nil when images array is empty" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: {
                      title: "Test",
                      images: []
                    })

      expect(saved.main_image).to be_nil
    end

    it "returns nil when no images key" do
      saved = build(:pwb_saved_property,
                    website: website,
                    property_data: { title: "Test" })

      expect(saved.main_image).to be_nil
    end
  end

  describe ".extract_price_cents" do
    it "extracts cents from Money-like hash" do
      data = { price: { cents: 27_500_000, currency_iso: "USD" } }
      expect(described_class.extract_price_cents(data)).to eq(27_500_000)
    end

    it "handles plain integer price" do
      data = { price: 450_000 }
      expect(described_class.extract_price_cents(data)).to eq(450_000)
    end

    it "handles string keys" do
      data = { "price" => { "cents" => 10_000_000, "currency_iso" => "EUR" } }
      expect(described_class.extract_price_cents(data)).to eq(10_000_000)
    end
  end
end
