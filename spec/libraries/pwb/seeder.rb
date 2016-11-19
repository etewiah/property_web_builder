require 'spec_helper'
require 'pwb/seeder'

module Pwb
  RSpec.describe 'Seeder' do
    before(:each) do
      Pwb::Seeder.seed!
    end

    it 'creates a landing page hero entry' do
      expect(Pwb::Content.find_by_key('landingPageHero')).to be_present
    end

    it 'creates an about_us entry' do
      expect(Pwb::Content.find_by_key('aboutUs')).to be_present
    end

    it 'creates 3 content-area-cols' do
      expect(Pwb::Content.where(tag: 'content-area-cols').count).to eq(3)
    end

  end
end
