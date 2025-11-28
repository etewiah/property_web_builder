# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Website, type: :model do
  describe 'multi-tenancy support' do
    before(:each) do
      # Clean up to ensure we're starting fresh
      Pwb::Website.delete_all
    end

    it 'allows multiple websites to be created' do
      website1 = FactoryBot.create(:pwb_website, subdomain: 'tenant1')
      website2 = FactoryBot.create(:pwb_website, subdomain: 'tenant2')
      website3 = FactoryBot.create(:pwb_website, subdomain: 'tenant3')
      
      expect(Pwb::Website.count).to eq(3)
      expect([website1.id, website2.id, website3.id].uniq.count).to eq(3)
    end
    
    it 'does not enforce ID=1 constraint' do
      # Create first website - should get whatever ID the sequence provides
      website1 = FactoryBot.create(:pwb_website,subdomain: 'first')
      
      # Create second website
      website2 = FactoryBot.create(:pwb_website, subdomain: 'second')
      
      # Both should succeed
      expect(website1.persisted?).to be true
      expect(website2.persisted?).to be true
      expect(website1.id).to be_present
      expect(website2.id).to be_present
      
      # IDs should be different
      expect(website1.id).not_to eq(website2.id)
    end

    it 'assigns sequential IDs automatically' do
      websites = []
      3.times do |i|
        websites << FactoryBot.create(:pwb_website, subdomain: "tenant#{i}")
      end

      # All IDs should be unique
      ids = websites.map(&:id)
      expect(ids.uniq.count).to eq(3)
    end

    it 'validates subdomain uniqueness' do
      FactoryBot.create(:pwb_website, subdomain: 'duplicate')
      
      duplicate_website = FactoryBot.build(:pwb_website, subdomain: 'duplicate')
      expect(duplicate_website).not_to be_valid
      expect(duplicate_website.errors[:subdomain]).to include('has already been taken')
    end

    it 'allows nil subdomains for multiple websites' do
      website1 = FactoryBot.create(:pwb_website, subdomain: nil)
      website2 = FactoryBot.create(:pwb_website, subdomain: nil)
      
      expect(website1.persisted?).to be true
      expect(website2.persisted?).to be true
    end
  end

  describe '.find_by_subdomain' do
    it 'finds website by case-insensitive subdomain' do
      website = FactoryBot.create(:pwb_website, subdomain: 'MyTenant')
      
      expect(Pwb::Website.find_by_subdomain('mytenant')).to eq(website)
      expect(Pwb::Website.find_by_subdomain('MYTENANT')).to eq(website)
      expect(Pwb::Website.find_by_subdomain('MyTenant')).to eq(website)
    end

    it 'returns nil for non-existent subdomain' do
      expect(Pwb::Website.find_by_subdomain('nonexistent')).to be_nil
    end
  end
end
