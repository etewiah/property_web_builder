require 'rails_helper'

RSpec.describe "Subdomain Multi-tenancy Data Isolation", type: :request do
  # Clear current website before each test
  before(:each) do
    Pwb::Current.reset
  end

  describe "Subdomain-based tenant resolution" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "tenant1", company_display_name: "Tenant 1 Corp") }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "tenant2", company_display_name: "Tenant 2 Corp") }

    # Properties for each tenant
    let!(:prop1) { Pwb::Prop.create!(website: website1, reference: "PROP-T1-001", visible: true, for_sale: true, price_sale_current_cents: 50000000, price_sale_current_currency: "EUR") }
    let!(:prop2) { Pwb::Prop.create!(website: website1, reference: "PROP-T1-002", visible: true, for_sale: true, price_sale_current_cents: 75000000, price_sale_current_currency: "EUR") }
    let!(:prop3) { Pwb::Prop.create!(website: website2, reference: "PROP-T2-001", visible: true, for_sale: true, price_sale_current_cents: 100000000, price_sale_current_currency: "EUR") }

    describe "Property isolation via subdomain" do
      it "returns only properties belonging to tenant1 subdomain" do
        query = <<~GQL
          query {
            searchProperties {
              id
              reference
            }
          }
        GQL

        # Simulate request from tenant1.example.com
        host! "tenant1.example.com"
        post "/graphql", params: { query: query }

        json = JSON.parse(response.body)
        properties = json["data"]["searchProperties"]

        expect(properties.length).to eq(2)
        references = properties.map { |p| p["reference"] }
        expect(references).to contain_exactly("PROP-T1-001", "PROP-T1-002")
        expect(references).not_to include("PROP-T2-001")
      end

      it "returns only properties belonging to tenant2 subdomain" do
        query = <<~GQL
          query {
            searchProperties {
              id
              reference
            }
          }
        GQL

        # Simulate request from tenant2.example.com
        host! "tenant2.example.com"
        post "/graphql", params: { query: query }

        json = JSON.parse(response.body)
        properties = json["data"]["searchProperties"]

        expect(properties.length).to eq(1)
        expect(properties.first["reference"]).to eq("PROP-T2-001")
        expect(properties.map { |p| p["reference"] }).not_to include("PROP-T1-001", "PROP-T1-002")
      end
    end

    describe "Header takes priority over subdomain" do
      it "uses X-Website-Slug header even when subdomain is present" do
        query = <<~GQL
          query {
            searchProperties {
              id
              reference
            }
          }
        GQL

        # Request from tenant1 subdomain but with tenant2 header
        host! "tenant1.example.com"
        post "/graphql", params: { query: query }, headers: { "X-Website-Slug" => "site2" }

        json = JSON.parse(response.body)
        properties = json["data"]["searchProperties"]

        # Should get tenant2's properties due to header priority
        expect(properties.length).to eq(1)
        expect(properties.first["reference"]).to eq("PROP-T2-001")
      end
    end

    describe "Cross-tenant data access prevention" do
      it "cannot access another tenant's property by ID via subdomain" do
        query = <<~GQL
          query($id: ID!) {
            findProperty(id: $id, locale: "en") {
              id
              reference
            }
          }
        GQL

        # Try to access tenant2's property from tenant1's subdomain
        host! "tenant1.example.com"
        post "/graphql", params: { query: query, variables: { id: prop3.id.to_s } }

        json = JSON.parse(response.body)

        # Should either return nil data or have errors (property not found in tenant's scope)
        # The find method raises RecordNotFound, so we expect an error response
        if json["errors"]
          expect(json["errors"]).to be_present
        else
          expect(json["data"]["findProperty"]).to be_nil
        end
      end
    end
  end

  describe "Page isolation via subdomain" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "agency1") }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "agency2") }

    let!(:page1) { Pwb::Page.create!(website: website1, slug: "about", visible: true) }
    let!(:page2) { Pwb::Page.create!(website: website2, slug: "about", visible: true) }

    it "returns the correct page for each subdomain" do
      query = <<~GQL
        query {
          findPage(slug: "about", locale: "en") {
            id
            slug
          }
        }
      GQL

      # Request from agency1 subdomain
      host! "agency1.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      page = json["data"]["findPage"]

      expect(page["id"].to_i).to eq(page1.id)
    end

    it "returns different page for different subdomain" do
      query = <<~GQL
        query {
          findPage(slug: "about", locale: "en") {
            id
            slug
          }
        }
      GQL

      # Request from agency2 subdomain
      host! "agency2.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      page = json["data"]["findPage"]

      expect(page["id"].to_i).to eq(page2.id)
    end
  end

  describe "Link isolation via subdomain" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "realestate1") }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "realestate2") }

    let!(:link1) { Pwb::Link.create!(website: website1, slug: "contact", placement: "top_nav", visible: true) }
    let!(:link2) { Pwb::Link.create!(website: website1, slug: "services", placement: "top_nav", visible: true) }
    let!(:link3) { Pwb::Link.create!(website: website2, slug: "about-us", placement: "top_nav", visible: true) }

    it "returns only links for the current subdomain tenant" do
      query = <<~GQL
        query {
          getTopNavLinks(locale: "en") {
            slug
          }
        }
      GQL

      host! "realestate1.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      links = json["data"]["getTopNavLinks"]

      expect(links.length).to eq(2)
      slugs = links.map { |l| l["slug"] }
      expect(slugs).to contain_exactly("contact", "services")
      expect(slugs).not_to include("about-us")
    end

    it "isolates links between different subdomains" do
      query = <<~GQL
        query {
          getTopNavLinks(locale: "en") {
            slug
          }
        }
      GQL

      host! "realestate2.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      links = json["data"]["getTopNavLinks"]

      expect(links.length).to eq(1)
      expect(links.first["slug"]).to eq("about-us")
    end
  end

  describe "Site details isolation via subdomain" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "alpha", company_display_name: "Alpha Properties") }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "beta", company_display_name: "Beta Realty") }

    it "returns correct site details for alpha subdomain" do
      query = <<~GQL
        query {
          getSiteDetails(locale: "en") {
            companyDisplayName
          }
        }
      GQL

      host! "alpha.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)

      # Debug: print response if there's an issue
      if json["data"].nil?
        puts "Response body: #{response.body}"
        puts "Errors: #{json['errors']}"
      end

      expect(json["data"]).not_to be_nil
      site = json["data"]["getSiteDetails"]

      expect(site["companyDisplayName"]).to eq("Alpha Properties")
    end

    it "returns correct site details for beta subdomain" do
      query = <<~GQL
        query {
          getSiteDetails(locale: "en") {
            companyDisplayName
          }
        }
      GQL

      host! "beta.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)

      # Debug: print response if there's an issue
      if json["data"].nil?
        puts "Response body: #{response.body}"
        puts "Errors: #{json['errors']}"
      end

      expect(json["data"]).not_to be_nil
      site = json["data"]["getSiteDetails"]

      expect(site["companyDisplayName"]).to eq("Beta Realty")
    end
  end

  describe "Reserved subdomains" do
    it "ignores www subdomain and uses default website" do
      # Create a default website that would be returned by unique_instance
      Pwb::Website.find_or_create_by!(id: 1) do |w|
        w.slug = "default"
        w.company_display_name = "Default Site"
      end

      query = <<~GQL
        query {
          getSiteDetails(locale: "en") {
            slug
          }
        }
      GQL

      host! "www.example.com"
      post "/graphql", params: { query: query }

      # Should fallback to default website, not try to find a "www" tenant
      expect(response).to have_http_status(:success)
    end

    it "ignores api subdomain and uses default website" do
      Pwb::Website.find_or_create_by!(id: 1) do |w|
        w.slug = "default"
      end

      query = <<~GQL
        query {
          getSiteDetails(locale: "en") {
            slug
          }
        }
      GQL

      host! "api.example.com"
      post "/graphql", params: { query: query }

      expect(response).to have_http_status(:success)
    end
  end

  describe "Case-insensitive subdomain matching" do
    let!(:website) { Pwb::Website.create!(slug: "mysite", subdomain: "myagency", company_display_name: "My Agency") }
    let!(:prop) { Pwb::Prop.create!(website: website, reference: "CASE-TEST", visible: true, for_sale: true, price_sale_current_cents: 10000000, price_sale_current_currency: "EUR") }

    it "matches subdomain case-insensitively" do
      query = <<~GQL
        query {
          searchProperties {
            reference
          }
        }
      GQL

      # Use uppercase subdomain
      host! "MYAGENCY.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      properties = json["data"]["searchProperties"]

      expect(properties.length).to eq(1)
      expect(properties.first["reference"]).to eq("CASE-TEST")
    end
  end

  describe "Fallback behavior" do
    it "uses default website when subdomain is not found" do
      default_website = Pwb::Website.find_or_create_by!(id: 1) do |w|
        w.slug = "default"
        w.company_display_name = "Default Fallback"
      end

      query = <<~GQL
        query {
          getSiteDetails(locale: "en") {
            companyDisplayName
          }
        }
      GQL

      host! "nonexistent.example.com"
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      site = json["data"]["getSiteDetails"]

      expect(site["companyDisplayName"]).to eq("Default Fallback")
    end
  end
end
