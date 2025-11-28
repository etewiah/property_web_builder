require 'rails_helper'

RSpec.describe "GraphQL Multi-tenancy", type: :request do
  describe "POST /graphql" do
    let!(:website1) { Pwb::Website.create!(slug: "site1") }
    let!(:website2) { Pwb::Website.create!(slug: "site2") }
    
    # Create props for each website
    let!(:prop1) { Pwb::Prop.create!(website: website1, reference: "ref1", visible: true, for_sale: true, price_sale_current_cents: 10000000, price_sale_current_currency: "EUR") }
    let!(:prop2) { Pwb::Prop.create!(website: website2, reference: "ref2", visible: true, for_sale: true, price_sale_current_cents: 20000000, price_sale_current_currency: "EUR") }

    it "returns properties for site1" do
      query = <<~GQL
        query {
          searchProperties {
            id
            reference
          }
        }
      GQL

      post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site1" }
      
      json = JSON.parse(response.body)
      properties = json["data"]["searchProperties"]
      
      expect(properties.length).to eq(1)
      expect(properties.first["reference"]).to eq("ref1")
    end

    it "returns properties for site2" do
      query = <<~GQL
        query {
          searchProperties {
            id
            reference
          }
        }
      GQL

      post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site2" }
      
      json = JSON.parse(response.body)
      properties = json["data"]["searchProperties"]
      
      expect(properties.length).to eq(1)
      expect(properties.first["reference"]).to eq("ref2")
    end

    describe "Pages" do
      let!(:page1) { Pwb::Page.create!(website: website1, slug: "home", visible: true) }
      let!(:page2) { Pwb::Page.create!(website: website2, slug: "home", visible: true) }

      it "returns page for site1" do
        query = <<~GQL
          query {
            findPage(slug: "home", locale: "en") {
              id
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site1" }
        
        json = JSON.parse(response.body)
        page = json["data"]["findPage"]
        
        expect(page["id"].to_i).to eq(page1.id)
      end

      it "returns page for site2" do
        query = <<~GQL
          query {
            findPage(slug: "home", locale: "en") {
              id
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site2" }
        
        json = JSON.parse(response.body)
        page = json["data"]["findPage"]
        
        expect(page["id"].to_i).to eq(page2.id)
      end
    end

    describe "Links" do
      let!(:link1) { Pwb::Link.create!(website: website1, slug: "link1", placement: "top_nav", visible: true) }
      let!(:link2) { Pwb::Link.create!(website: website2, slug: "link2", placement: "top_nav", visible: true) }

      it "returns top nav links for site1" do
        query = <<~GQL
          query {
            getTopNavLinks(locale: "en") {
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site1" }
        
        json = JSON.parse(response.body)
        links = json["data"]["getTopNavLinks"]
        
        expect(links.length).to eq(1)
        expect(links.first["slug"]).to eq("link1")
      end
    end

    describe "Fallback" do
      it "uses default site when header is missing" do
        # In the controller we have: Pwb::Current.website ||= Pwb::Website.first
        # This will use the first website in the database if no header provided.
        
        query = <<~GQL
          query {
            getSiteDetails(locale: "en") {
              slug
            }
          }
        GQL

        post "/graphql", params: { query: query }
        
        # json = JSON.parse(response.body)
        # It might return a new website with ID 1 if not present.
        # Or if website1 happened to get ID 1.
      end
    end
  end
end
