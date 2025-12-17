# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
FactoryBot.define do
  factory :pwb_content_photo, class: "Pwb::ContentPhoto", aliases: [:content_photo] do
    association :content, factory: :pwb_content

    trait :with_image do
      after(:build) do |photo|
        photo.image.attach(
          io: StringIO.new('fake image data'),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
