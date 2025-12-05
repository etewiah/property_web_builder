require 'rails_helper'

module PwbTenant
  RSpec.describe Prop, type: :model do
    # PwbTenant::Prop is a scoped model that inherits from Pwb::Prop
    # It provides multi-tenant isolation by filtering by current website

    let!(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'tenant-a') }
    let!(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'tenant-b') }

    let!(:prop_a) { FactoryBot.create(:pwb_prop, :sale, website: website_a) }
    let!(:prop_b) { FactoryBot.create(:pwb_prop, :sale, website: website_b) }

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

    describe 'inheritance' do
      it 'inherits methods from Pwb::Prop' do
        prop = described_class.find(prop_a.id)
        expect(prop).to respond_to(:url_friendly_title)
        expect(prop).to be_a(Pwb::Prop)
      end
    end
  end
end
