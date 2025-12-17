# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
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
  end
end
