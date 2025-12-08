# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Agency, type: :model do
  describe 'multi-tenancy support' do
    it 'allows multiple agencies for different websites' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'mt-tenant1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'mt-tenant2')

      agency1 = ActsAsTenant.with_tenant(website1) do
        Pwb::Agency.create!(website: website1, company_name: 'MT Agency One')
      end
      agency2 = ActsAsTenant.with_tenant(website2) do
        Pwb::Agency.create!(website: website2, company_name: 'MT Agency Two')
      end

      expect(agency1.website).to eq(website1)
      expect(agency2.website).to eq(website2)
      expect(agency1.persisted?).to be true
      expect(agency2.persisted?).to be true
    end

    it 'does not raise singularity exception when creating multiple agencies' do
      # This used to fail with "There can be only one agency"
      agencies = []
      expect {
        3.times do |i|
          website = FactoryBot.create(:pwb_website, subdomain: "mt-sing-tenant#{i}")
          ActsAsTenant.with_tenant(website) do
            agencies << Pwb::Agency.create!(website: website, company_name: "MT Sing Agency #{i}")
          end
        end
      }.not_to raise_error

      expect(agencies.length).to eq(3)
      expect(agencies.all?(&:persisted?)).to be true
    end

    it 'does not enforce ID=1 constraint' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'id-test1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'id-test2')

      agency1 = ActsAsTenant.with_tenant(website1) do
        Pwb::Agency.create!(website: website1, company_name: 'First Agency')
      end
      agency2 = ActsAsTenant.with_tenant(website2) do
        Pwb::Agency.create!(website: website2, company_name: 'Second Agency')
      end

      expect(agency1.persisted?).to be true
      expect(agency2.persisted?).to be true
      expect(agency1.id).to be_present
      expect(agency2.id).to be_present

      # IDs should be different
      expect(agency1.id).not_to eq(agency2.id)
    end

    it 'allows agencies with websites only' do
      # Note: PwbTenant::Agency requires tenant context - agencies without websites
      # should use Pwb::Agency directly for cross-tenant operations
      website1 = FactoryBot.create(:pwb_website, subdomain: 'orphan-test1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'orphan-test2')

      agency1 = ActsAsTenant.with_tenant(website1) do
        Pwb::Agency.create!(website: website1, company_name: 'Orphan Agency 1')
      end
      agency2 = ActsAsTenant.with_tenant(website2) do
        Pwb::Agency.create!(website: website2, company_name: 'Orphan Agency 2')
      end

      expect(agency1.persisted?).to be true
      expect(agency2.persisted?).to be true
    end

    it 'associates agency with correct website' do
      website = FactoryBot.create(:pwb_website, subdomain: 'test-agency')
      # Factory already creates an agency for the website
      agency = website.agency

      expect(agency).to be_present
      expect(agency.website_id).to eq(website.id)
      expect(website.reload.agency.id).to eq(agency.id)
    end
  end
end
