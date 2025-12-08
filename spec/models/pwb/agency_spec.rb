require 'rails_helper'

module Pwb
  RSpec.describe Agency, type: :model do
    let(:website) { FactoryBot.create(:pwb_website, subdomain: 'agency-test') }

    before(:each) do
      Pwb::Current.reset
    end

    let(:agency) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_agency, website: website)
      end
    end

    it 'has a valid factory' do
      expect(agency).to be_valid
    end
  end
end
