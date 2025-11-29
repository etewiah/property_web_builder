# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Agency, type: :model do
  describe 'multi-tenancy support' do
    it 'allows multiple agencies for different websites' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'mt-tenant1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'mt-tenant2')
      
      agency1 = FactoryBot.create(:pwb_agency, website: website1, company_name: 'MT Agency One')
      agency2 = FactoryBot.create(:pwb_agency, website: website2, company_name: 'MT Agency Two')
      
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
          agencies << FactoryBot.create(:pwb_agency, website: website, company_name: "MT Sing Agency #{i}")
        end
      }.not_to raise_error
      
      expect(agencies.length).to eq(3)
      expect(agencies.all?(&:persisted?)).to be true
    end

    it 'does not enforce ID=1 constraint' do
      agency1 = FactoryBot.create(:pwb_agency, company_name: 'First Agency')
      agency2 = FactoryBot.create(:pwb_agency, company_name: 'Second Agency')
      
      expect(agency1.persisted?).to be true
      expect(agency2.persisted?).to be true
      expect(agency1.id).to be_present
      expect(agency2.id).to be_present
      
      # IDs should be different
      expect(agency1.id).not_to eq(agency2.id)
    end

    it 'allows multiple agencies without websites' do
      agency1 = FactoryBot.create(:pwb_agency, website: nil, company_name: 'Orphan Agency 1')
      agency2 = FactoryBot.create(:pwb_agency, website: nil, company_name: 'Orphan Agency 2')
      
      expect(agency1.persisted?).to be true
      expect(agency2.persisted?).to be true
      expect(agency1.website).to be_nil
      expect(agency2.website).to be_nil
    end

    it 'associates agency with correct website' do
      website = FactoryBot.create(:pwb_website, subdomain: 'test-agency')
      agency = FactoryBot.create(:pwb_agency, website: website, company_name: 'Test Company')
      
      expect(agency.website_id).to eq(website.id)
      expect(website.agency).to eq(agency)
    end
  end
end
