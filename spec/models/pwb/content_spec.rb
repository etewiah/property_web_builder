# require 'rails_helper'
require 'spec_helper'

module Pwb
  RSpec.describe Content, type: :model do
    # pending "add some examples to (or delete) #{__FILE__}"
    let(:content) { FactoryBot.create(:pwb_content) }
    # create(:alchemy_element, name: 'headline', create_contents_after_create: true) }

    it 'has a valid factory' do
      expect(content).to be_valid
    end

    describe "associations" do
      it "belongs to website" do
        content = Content.new
        expect(content).to respond_to(:website)
      end
    end

    describe "multi-tenancy" do
      # Note: Content currently has a global unique index on `key`.
      # If content becomes tenant-specific, this index should be scoped
      # by website_id similar to how links and pages are scoped.
      #
      # See: index_pwb_contents_on_key in db/schema.rb
      #
      # If you encounter errors like:
      #   PG::UniqueViolation: duplicate key value violates unique constraint "index_pwb_contents_on_key"
      # when seeding content for multiple tenants, you'll need to:
      # 1. Create a migration to change the unique index to include website_id
      # 2. Update the Content model to validate uniqueness scoped to website

      it "can be associated with a website" do
        website = Website.create!(slug: "test-content-site")
        content = Content.create!(key: "tenant_content", website: website)
        expect(content.website).to eq(website)
      end
    end

    # it "is invalid without a key" do
    #   ::FactoryBot.build(:pwb_content, key: nil).should_not be_valid
    # end
  end
end
