# frozen_string_literal: true

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
FactoryBot.define do
  factory :pwb_address, class: 'Pwb::Address' do
  end
end
