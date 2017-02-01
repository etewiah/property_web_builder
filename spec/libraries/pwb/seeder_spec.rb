require 'spec_helper'
require 'pwb/seeder'

module Pwb
  RSpec.describe 'Seeder' do
    before(:all) do
      Pwb::Seeder.seed!
    end
    it 'creates a landing page hero entry' do
      expect(Pwb::Content.find_by_key('landingCarousel1')).to be_present
    end

    it 'creates an about_us entry' do
      expect(Pwb::Content.find_by_key('aboutUs')).to be_present
    end

    it 'creates 3 content-area-cols' do
      expect(Pwb::Content.where(tag: 'content-area-cols').count).to eq(3)
    end

    it 'creates 4 prop entries' do
      expect(Pwb::Prop.count).to eq(4)
    end
  end
end
