require 'rails_helper'

module Pwb
  RSpec.describe Link, type: :model do
    describe "associations" do
      it "belongs to website" do
        link = Link.new
        expect(link).to respond_to(:website)
        expect(link).to respond_to(:website=)
      end

      it "belongs to page" do
        link = Link.new
        expect(link).to respond_to(:page)
        expect(link).to respond_to(:page=)
      end
    end

    describe "multi-tenancy uniqueness constraints" do
      let!(:website1) { Website.create!(slug: "site-1", subdomain: "site1") }
      let!(:website2) { Website.create!(slug: "site-2", subdomain: "site2") }

      context "when creating links with the same slug for different websites" do
        it "allows the same slug across different websites" do
          link1 = Link.create!(website: website1, slug: "top_nav_home", placement: :top_nav)
          link2 = Link.create!(website: website2, slug: "top_nav_home", placement: :top_nav)

          expect(link1).to be_persisted
          expect(link2).to be_persisted
          expect(link1.slug).to eq(link2.slug)
          expect(link1.website_id).not_to eq(link2.website_id)
        end

        it "prevents duplicate slugs within the same website" do
          Link.create!(website: website1, slug: "top_nav_home", placement: :top_nav)

          expect {
            Link.create!(website: website1, slug: "top_nav_home", placement: :footer)
          }.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end

      context "when seeding data for multiple tenants" do
        let(:standard_link_slugs) { %w[top_nav_home top_nav_about footer_contact footer_legal] }

        it "can create the same set of standard links for each tenant" do
          # Simulate what the seeder does for each tenant
          standard_link_slugs.each do |slug|
            Link.create!(website: website1, slug: slug, placement: :top_nav)
          end

          # Should be able to create the same links for website2
          expect {
            standard_link_slugs.each do |slug|
              Link.create!(website: website2, slug: slug, placement: :top_nav)
            end
          }.not_to raise_error

          expect(website1.links.count).to eq(4)
          expect(website2.links.count).to eq(4)
        end
      end

      context "scoped queries" do
        before do
          Link.create!(website: website1, slug: "nav_home", placement: :top_nav, visible: true)
          Link.create!(website: website1, slug: "nav_about", placement: :top_nav, visible: true)
          Link.create!(website: website2, slug: "nav_home", placement: :top_nav, visible: true)
          Link.create!(website: website2, slug: "nav_contact", placement: :footer, visible: true)
        end

        it "returns only links belonging to a specific website" do
          expect(website1.links.pluck(:slug)).to contain_exactly("nav_home", "nav_about")
          expect(website2.links.pluck(:slug)).to contain_exactly("nav_home", "nav_contact")
        end

        it "finds links by slug within website scope" do
          link = website1.links.find_by(slug: "nav_home")
          expect(link.website_id).to eq(website1.id)
        end
      end
    end

    describe "placements" do
      it "supports top_nav placement" do
        link = Link.new(placement: :top_nav)
        expect(link.placement).to eq("top_nav")
      end

      it "supports footer placement" do
        link = Link.new(placement: :footer)
        expect(link.placement).to eq("footer")
      end

      it "supports social_media placement" do
        link = Link.new(placement: :social_media)
        expect(link.placement).to eq("social_media")
      end

      it "supports admin placement" do
        link = Link.new(placement: :admin)
        expect(link.placement).to eq("admin")
      end
    end

    describe "scopes" do
      let!(:website) { Website.create!(slug: "test-site") }

      before do
        Link.create!(website: website, slug: "visible_top", placement: :top_nav, visible: true, sort_order: 2)
        Link.create!(website: website, slug: "hidden_top", placement: :top_nav, visible: false, sort_order: 1)
        Link.create!(website: website, slug: "visible_footer", placement: :footer, visible: true, sort_order: 1)
        Link.create!(website: website, slug: "visible_admin", placement: :admin, visible: true, sort_order: 1)
      end

      it "ordered_visible_top_nav returns only visible top_nav links ordered by sort_order" do
        links = Link.ordered_visible_top_nav
        expect(links.pluck(:slug)).to eq(["visible_top"])
      end

      it "ordered_visible_footer returns only visible footer links" do
        links = Link.ordered_visible_footer
        expect(links.pluck(:slug)).to eq(["visible_footer"])
      end

      it "ordered_visible_admin returns only visible admin links" do
        links = Link.ordered_visible_admin
        expect(links.pluck(:slug)).to eq(["visible_admin"])
      end
    end
  end
end
