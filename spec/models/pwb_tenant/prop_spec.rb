require 'rails_helper'

module PwbTenant
  RSpec.describe Prop, type: :model do
    let!(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'tenant-a') }
    let!(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'tenant-b') }
    
    let!(:prop_a) { FactoryBot.create(:pwb_prop, website: website_a, title: 'Prop A') }
    let!(:prop_b) { FactoryBot.create(:pwb_prop, website: website_b, title: 'Prop B') }
    
    before do
      # Simulate request context
      allow(Pwb::Current).to receive(:website).and_return(website_a)
    end
    
    describe 'default scope' do
      it 'only returns props for current website' do
        ids = described_class.all.map(&:id)
        expect(ids).to include(prop_a.id)
        expect(ids).not_to include(prop_b.id)
      end
      
      it 'finds prop belonging to current website' do
        found_prop = described_class.find(prop_a.id)
        expect(found_prop.id).to eq(prop_a.id)
        expect(found_prop).to be_a(PwbTenant::Prop)
      end
      
      it 'raises RecordNotFound for prop belonging to other website' do
        expect {
          described_class.find(prop_b.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    
    describe 'creation' do
      it 'automatically assigns current website' do
        new_prop = described_class.create!(title: 'New Prop')
        expect(new_prop.website_id).to eq(website_a.id)
      end
      
      it 'allows overriding website if needed (though not recommended)' do
        new_prop = described_class.create!(title: 'Override Prop', website: website_b)
        # It should be created for website_b
        expect(new_prop.website_id).to eq(website_b.id)
        # But it shouldn't be visible in current scope
        expect(described_class.find_by(id: new_prop.id)).to be_nil
      end
    end
    
    describe 'inheritance' do
      it 'inherits methods from Pwb::Prop' do
        expect(prop_a).to respond_to(:url_friendly_title)
        expect(prop_a).to be_a(Pwb::Prop)
      end
    end
  end
end
