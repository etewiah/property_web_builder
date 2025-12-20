# == Schema Information
#
# Table name: pwb_addresses
#
#  id             :integer          not null, primary key
#  city           :string
#  country        :string
#  latitude       :float
#  longitude      :float
#  postal_code    :string
#  region         :string
#  street_address :string
#  street_number  :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require 'rails_helper'

module Pwb
  RSpec.describe Address, type: :model do
    let(:address) { FactoryBot.create(:pwb_address) }

    it 'has a valid factory' do
      expect(address).to be_valid
    end
  end
end
