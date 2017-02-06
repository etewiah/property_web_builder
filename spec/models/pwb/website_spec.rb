require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    
    let(:website) {  Website.unique_instance || FactoryGirl.create(:pwb_website) }
    # let(:website2) { FactoryGirl.create(:pwb_website) }

    it 'has correct unique_instance' do
      expect(Website.unique_instance.id).to eq(1)
    end

    it 'has correct defaults' do
      expect(Website.unique_instance.supported_locales).to eq(["en-UK"])
      
    end

    it 'has a valid factory' do
      expect(website).to be_valid
    end
  end
end
