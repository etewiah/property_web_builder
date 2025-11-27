require 'rails_helper'

# These specs ensure that database uniqueness constraints are properly scoped
# for multi-tenancy. When a unique index is not scoped by website_id, creating
# the same data for multiple tenants will fail with duplicate key violations.
#
# This spec was created to catch issues like the one where pwb_links had a
# global unique index on slug, causing tenant creation to fail when seeding
# standard navigation links.

module Pwb
  RSpec.describe "Multi-tenancy uniqueness constraints", type: :model do
    let!(:website1) { Website.create!(slug: "tenant-alpha", subdomain: "alpha") }
    let!(:website2) { Website.create!(slug: "tenant-beta", subdomain: "beta") }

    describe "Link slug uniqueness" do
      # This was the original bug: links had a global unique index on slug
      # which prevented creating the same standard links for multiple tenants

      it "allows same slug across different websites" do
        link1 = Link.create!(website: website1, slug: "top_nav_home", placement: :top_nav)
        link2 = Link.create!(website: website2, slug: "top_nav_home", placement: :top_nav)

        expect(link1).to be_persisted
        expect(link2).to be_persisted
      end

      it "prevents duplicate slugs within same website" do
        Link.create!(website: website1, slug: "unique_link", placement: :top_nav)

        expect {
          Link.create!(website: website1, slug: "unique_link", placement: :footer)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      context "seeding standard navigation links for multiple tenants" do
        let(:standard_nav_links) do
          %w[
            top_nav_home
            top_nav_search
            top_nav_properties
            top_nav_about
            top_nav_contact
            footer_home
            footer_about
            footer_legal
            footer_privacy
          ]
        end

        it "can create all standard links for tenant 1" do
          expect {
            standard_nav_links.each do |slug|
              website1.links.create!(slug: slug, placement: :top_nav)
            end
          }.not_to raise_error

          expect(website1.links.count).to eq(standard_nav_links.count)
        end

        it "can create identical standard links for tenant 2 after tenant 1" do
          # First create for tenant 1
          standard_nav_links.each do |slug|
            website1.links.create!(slug: slug, placement: :top_nav)
          end

          # Then create for tenant 2 - this should not fail
          expect {
            standard_nav_links.each do |slug|
              website2.links.create!(slug: slug, placement: :top_nav)
            end
          }.not_to raise_error

          expect(website2.links.count).to eq(standard_nav_links.count)
        end
      end
    end

    describe "Page slug uniqueness" do
      it "allows same slug across different websites" do
        page1 = Page.create!(website: website1, slug: "home")
        page2 = Page.create!(website: website2, slug: "home")

        expect(page1).to be_persisted
        expect(page2).to be_persisted
      end

      it "prevents duplicate slugs within same website" do
        Page.create!(website: website1, slug: "about-us")

        expect {
          Page.create!(website: website1, slug: "about-us")
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      context "seeding standard pages for multiple tenants" do
        let(:standard_pages) { %w[home about-us contact-us legal privacy sell] }

        it "can create all standard pages for both tenants" do
          # Create for tenant 1
          standard_pages.each do |slug|
            website1.pages.create!(slug: slug)
          end

          # Create for tenant 2
          expect {
            standard_pages.each do |slug|
              website2.pages.create!(slug: slug)
            end
          }.not_to raise_error

          expect(website1.pages.count).to eq(standard_pages.count)
          expect(website2.pages.count).to eq(standard_pages.count)
        end
      end
    end

    describe "Content key uniqueness" do
      # Content key is now scoped to website_id, allowing different websites
      # to have content with the same key

      it "has website association" do
        content = Content.create!(website: website1, key: "test_content")
        expect(content.website).to eq(website1)
      end

      it "allows same key across different websites" do
        content1 = Content.create!(website: website1, key: "footer_content")
        content2 = Content.create!(website: website2, key: "footer_content")

        expect(content1).to be_persisted
        expect(content2).to be_persisted
        expect(content1.key).to eq(content2.key)
        expect(content1.website_id).not_to eq(content2.website_id)
      end

      it "prevents duplicate keys within the same website" do
        Content.create!(website: website1, key: "unique_content")

        expect {
          Content.create!(website: website1, key: "unique_content")
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      context "seeding standard content for multiple tenants" do
        let(:standard_content_keys) { %w[footer_content_html landing_hero about_us_services] }

        it "can create all standard content for both tenants" do
          # Create for tenant 1
          standard_content_keys.each do |key|
            website1.contents.create!(key: key)
          end

          # Create for tenant 2 - should not fail
          expect {
            standard_content_keys.each do |key|
              website2.contents.create!(key: key)
            end
          }.not_to raise_error

          expect(Content.where(website: website1).count).to eq(standard_content_keys.count)
          expect(Content.where(website: website2).count).to eq(standard_content_keys.count)
        end
      end
    end

    describe "Prop (Property) uniqueness" do
      it "allows properties with same reference across different websites" do
        prop1 = Prop.create!(
          website: website1,
          reference: "PROP-001",
          price_sale_current_cents: 100000,
          price_sale_current_currency: "EUR"
        )
        prop2 = Prop.create!(
          website: website2,
          reference: "PROP-001",
          price_sale_current_cents: 200000,
          price_sale_current_currency: "EUR"
        )

        expect(prop1).to be_persisted
        expect(prop2).to be_persisted
        expect(prop1.reference).to eq(prop2.reference)
      end
    end

    describe "Agency uniqueness" do
      # Website#agency now uses the has_one :agency association properly,
      # allowing each website to have its own agency.

      it "allows agencies to be associated with different websites" do
        agency1 = Agency.create!(website: website1, company_name: "Alpha Real Estate")
        agency2 = Agency.create!(website: website2, company_name: "Beta Properties")

        expect(agency1).to be_persisted
        expect(agency2).to be_persisted
        expect(agency1.website).to eq(website1)
        expect(agency2.website).to eq(website2)
      end

      it "allows agencies with same company name across different websites" do
        agency1 = Agency.create!(website: website1, company_name: "Best Realty")
        agency2 = Agency.create!(website: website2, company_name: "Best Realty")

        expect(agency1).to be_persisted
        expect(agency2).to be_persisted
      end

      it "retrieves the correct agency via website association" do
        agency1 = Agency.create!(website: website1, company_name: "Alpha Real Estate")
        agency2 = Agency.create!(website: website2, company_name: "Beta Properties")

        # The has_one association should return the correct agency for each website
        expect(website1.reload.agency).to eq(agency1)
        expect(website2.reload.agency).to eq(agency2)
      end

      it "can build agency through website association" do
        agency = website1.build_agency(company_name: "New Agency")
        agency.save!

        expect(website1.agency).to eq(agency)
        expect(agency.website).to eq(website1)
      end
    end

    describe "Website isolation" do
      before do
        # Set up data for both websites
        @link1 = Link.create!(website: website1, slug: "nav_home", placement: :top_nav)
        @link2 = Link.create!(website: website2, slug: "nav_home", placement: :top_nav)
        @page1 = Page.create!(website: website1, slug: "home")
        @page2 = Page.create!(website: website2, slug: "home")
        @prop1 = Prop.create!(
          website: website1,
          reference: "REF-1",
          price_sale_current_cents: 100000,
          price_sale_current_currency: "EUR"
        )
        @prop2 = Prop.create!(
          website: website2,
          reference: "REF-1",
          price_sale_current_cents: 200000,
          price_sale_current_currency: "EUR"
        )
      end

      it "scopes links to their website" do
        expect(website1.links).to include(@link1)
        expect(website1.links).not_to include(@link2)
        expect(website2.links).to include(@link2)
        expect(website2.links).not_to include(@link1)
      end

      it "scopes pages to their website" do
        expect(website1.pages).to include(@page1)
        expect(website1.pages).not_to include(@page2)
      end

      it "scopes properties to their website" do
        expect(website1.props).to include(@prop1)
        expect(website1.props).not_to include(@prop2)
      end

      it "finds records by slug within website scope" do
        # Both websites have a "nav_home" link
        found_link1 = website1.links.find_by(slug: "nav_home")
        found_link2 = website2.links.find_by(slug: "nav_home")

        expect(found_link1).to eq(@link1)
        expect(found_link2).to eq(@link2)
        expect(found_link1).not_to eq(found_link2)
      end
    end

    describe "Deleting a tenant" do
      before do
        # Create data for website1
        Link.create!(website: website1, slug: "test_link", placement: :top_nav)
        Page.create!(website: website1, slug: "test_page")
        Prop.create!(
          website: website1,
          reference: "TEST-PROP",
          price_sale_current_cents: 100000,
          price_sale_current_currency: "EUR"
        )
      end

      it "allows recreating the same data after tenant deletion" do
        # Store the slug we'll reuse
        link_slug = "test_link"

        # Verify the link exists
        expect(website1.links.find_by(slug: link_slug)).to be_present

        # Delete website1's link
        website1.links.destroy_all

        # Should be able to recreate
        expect {
          Link.create!(website: website1, slug: link_slug, placement: :top_nav)
        }.not_to raise_error
      end
    end
  end
end
