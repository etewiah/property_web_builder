require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    let(:website) { Website.create!(slug: "test-site") }

    it "has many props" do
      prop = Prop.create!(website: website, reference: "ref1", price_sale_current_cents: 100000, price_sale_current_currency: "EUR")
      expect(website.props).to include(prop)
    end

    it "has many pages" do
      page = Page.create!(website: website, slug: "home")
      expect(website.pages).to include(page)
    end

    it "has many contents" do
      content = Content.create!(website: website, key: "test")
      expect(website.contents).to include(content)
    end

    it "has many links" do
      link = Link.create!(website: website, slug: "link1")
      expect(website.links).to include(link)
    end

    it "has one agency" do
      agency = Agency.create!(website: website, company_name: "Test Agency")
      expect(website.agency).to eq(agency)
    end
    
    describe ".unique_instance" do
      it "returns the website with ID 1 or creates it" do
        # Ensure no websites exist
        Website.delete_all
        
        website = Website.unique_instance
        expect(website.id).to eq(1)
        
        # Calling it again returns the same instance
        expect(Website.unique_instance).to eq(website)
      end
    end
  end
end
