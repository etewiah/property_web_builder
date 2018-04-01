require 'spec_helper'
require 'pwb/importer'

module Pwb
  RSpec.describe 'Importer' do

    it 'imports properties using demo config correctly' do
      VCR.use_cassette('importer/rerenting') do
        Pwb::Importer.import!
        expect(Prop.last.count_bathrooms).to eq(2)
      end
    end

  end
end
