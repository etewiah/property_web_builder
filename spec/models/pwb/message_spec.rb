require 'rails_helper'

module Pwb
  RSpec.describe Message, type: :model do
    let(:website) { FactoryBot.create(:pwb_website, subdomain: 'message-test') }

    let(:message) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_message, website: website)
      end
    end

    before(:each) do
      Pwb::Current.reset
    end

    it 'has a valid factory' do
      expect(message).to be_valid
    end
  end
end
