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

    describe "subdomain validations" do
      it "allows valid subdomains" do
        website = Website.new(slug: "test", subdomain: "myagency")
        expect(website).to be_valid
      end

      it "allows subdomains with hyphens" do
        website = Website.new(slug: "test", subdomain: "my-real-estate")
        expect(website).to be_valid
      end

      it "allows subdomains with numbers" do
        website = Website.new(slug: "test", subdomain: "agency123")
        expect(website).to be_valid
      end

      it "rejects subdomains starting with hyphen" do
        website = Website.new(slug: "test", subdomain: "-invalid")
        expect(website).not_to be_valid
        expect(website.errors[:subdomain]).to be_present
      end

      it "rejects subdomains ending with hyphen" do
        website = Website.new(slug: "test", subdomain: "invalid-")
        expect(website).not_to be_valid
        expect(website.errors[:subdomain]).to be_present
      end

      it "rejects subdomains with special characters" do
        website = Website.new(slug: "test", subdomain: "my_agency")
        expect(website).not_to be_valid
        expect(website.errors[:subdomain]).to be_present
      end

      it "rejects subdomains that are too short" do
        website = Website.new(slug: "test", subdomain: "a")
        expect(website).not_to be_valid
        expect(website.errors[:subdomain]).to be_present
      end

      it "rejects reserved subdomains" do
        %w[www api admin app mail localhost].each do |reserved|
          website = Website.new(slug: "test-#{reserved}", subdomain: reserved)
          expect(website).not_to be_valid
          expect(website.errors[:subdomain]).to include("is reserved and cannot be used")
        end
      end

      it "enforces subdomain uniqueness" do
        Website.create!(slug: "first", subdomain: "unique-subdomain")
        website2 = Website.new(slug: "second", subdomain: "unique-subdomain")
        expect(website2).not_to be_valid
        expect(website2.errors[:subdomain]).to be_present
      end

      it "enforces case-insensitive subdomain uniqueness" do
        Website.create!(slug: "first", subdomain: "mysite")
        website2 = Website.new(slug: "second", subdomain: "MYSITE")
        expect(website2).not_to be_valid
      end

      it "allows blank subdomain" do
        website = Website.new(slug: "test", subdomain: nil)
        expect(website).to be_valid

        website2 = Website.new(slug: "test2", subdomain: "")
        expect(website2).to be_valid
      end
    end

    describe ".find_by_subdomain" do
      let!(:website1) { Website.create!(slug: "site1", subdomain: "alpha") }
      let!(:website2) { Website.create!(slug: "site2", subdomain: "beta") }

      it "finds website by exact subdomain" do
        expect(Website.find_by_subdomain("alpha")).to eq(website1)
        expect(Website.find_by_subdomain("beta")).to eq(website2)
      end

      it "finds website case-insensitively" do
        expect(Website.find_by_subdomain("ALPHA")).to eq(website1)
        expect(Website.find_by_subdomain("Alpha")).to eq(website1)
        expect(Website.find_by_subdomain("BETA")).to eq(website2)
      end

      it "returns nil for non-existent subdomain" do
        expect(Website.find_by_subdomain("nonexistent")).to be_nil
      end

      it "returns nil for blank subdomain" do
        expect(Website.find_by_subdomain("")).to be_nil
        expect(Website.find_by_subdomain(nil)).to be_nil
      end
    end
  end
end
