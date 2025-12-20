# == Schema Information
#
# Table name: pwb_website_photos
#
#  id           :bigint           not null, primary key
#  description  :string
#  external_url :string
#  file_size    :integer
#  folder       :string           default("weebrix")
#  image        :string
#  photo_key    :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  website_id   :bigint
#
# Indexes
#
#  index_pwb_website_photos_on_photo_key   (photo_key)
#  index_pwb_website_photos_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
