# frozen_string_literal: true

# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
# == Schema Information
#
# Table name: pwb_prop_photos
# Database name: primary
#
#  id              :integer          not null, primary key
#  description     :string
#  external_url    :string
#  file_size       :integer
#  folder          :string
#  image           :string
#  sort_order      :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  prop_id         :integer
#  realty_asset_id :uuid
#
# Indexes
#
#  index_pwb_prop_photos_on_prop_id          (prop_id)
#  index_pwb_prop_photos_on_realty_asset_id  (realty_asset_id)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
FactoryBot.define do
  factory :pwb_prop_photo, class: "Pwb::PropPhoto", aliases: [:prop_photo] do
    association :realty_asset, factory: :pwb_realty_asset

    trait :with_image do
      after(:build) do |photo|
        photo.image.attach(
          io: StringIO.new('fake image data'),
          filename: 'property_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    # Alias for clarity - same as :with_image
    trait :with_real_image do
      after(:build) do |photo|
        # Use a real test image file if available, otherwise use fake data
        test_image_path = Rails.root.join('spec/fixtures/files/test_image.jpg')
        if File.exist?(test_image_path)
          photo.image.attach(
            io: File.open(test_image_path),
            filename: 'test_property_image.jpg',
            content_type: 'image/jpeg'
          )
        else
          photo.image.attach(
            io: StringIO.new('fake image data'),
            filename: 'property_image.jpg',
            content_type: 'image/jpeg'
          )
        end
      end
    end

    trait :with_external_url do
      external_url { 'https://external-cdn.example.com/property-image.jpg' }
    end
  end
end
