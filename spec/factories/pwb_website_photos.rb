FactoryBot.define do
  factory :pwb_website_photo, class: 'Pwb::WebsitePhoto', aliases: [:website_photo] do
    association :website, factory: :pwb_website

    trait :with_image do
      after(:build) do |photo|
        photo.image.attach(
          io: StringIO.new('fake image data'),
          filename: 'website_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
