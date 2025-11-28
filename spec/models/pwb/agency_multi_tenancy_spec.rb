# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Agency, type: :model do
  describe 'multi-tenancy support' do
    before(:each) do
      # Clean up to ensure we're starting fresh
      Pwb::Agency.delete_all
      Pwb::Website.delete_all
    end

    it 'allows multiple agencies for different websites' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'tenant1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'tenant2')
      
      agency1 = FactoryBot.create(:pwb_agency, website: website1, company_name: 'Agency One')
      agency2 = FactoryBot.create(:pwb_agency, website: website2, company_name: 'Agency Two')
      
      expect(Pwb::Agency.count).to eq(2)
      expect(agency1.website).to eq(website1)
      expect(agency2.website).to eq(website2)
    end
    
    it 'does not raise singularity exception when creating multiple agencies' do
      # This used to fail with "There can be only one agency"
      expect {
        3.times do |i|
          website = FactoryBot.create(:pwb_website, subdomain: "tenant#{i}")
          FactoryBot.create(:pwb_agency, website: website, company_name: "Agency #{i}")
        end
      }.not_to raise_error
      
      expect(Pwb::Agency.count).to eq(3)
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
