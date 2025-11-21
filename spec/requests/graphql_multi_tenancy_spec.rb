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
  end
end
