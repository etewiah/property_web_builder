require 'rails_helper'

module Pwb
  RSpec.describe Content, type: :model do
    let(:website) { FactoryBot.create(:pwb_website) }
    let(:content) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_content, website: website)
      end
    end

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
      # Content key uniqueness is now scoped to website_id, allowing different
      # websites to have content with the same key. This is essential for
      # multi-tenant setups where each tenant needs their own content.
      #
      # See: index_pwb_contents_on_website_id_and_key in db/schema.rb

      it "can be associated with a website" do
        website = Website.create!(slug: "test-content-site")
        content = Content.create!(key: "tenant_content", website: website)
        expect(content.website).to eq(website)
      end

      it "allows same key for different websites" do
        website1 = Website.create!(slug: "site-1")
        website2 = Website.create!(slug: "site-2")

        content1 = Content.create!(key: "shared_key", website: website1)
        content2 = Content.create!(key: "shared_key", website: website2)

        expect(content1).to be_persisted
        expect(content2).to be_persisted
      end
    end

    # it "is invalid without a key" do
    #   ::FactoryBot.build(:pwb_content, key: nil).should_not be_valid
    # end
  end
end
