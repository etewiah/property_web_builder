# https://til.codes/testing-carrierwave-file-uploads-with-rspec-and-factorygirl/
# == Schema Information
#
# Table name: pwb_content_photos
#
#  id           :integer          not null, primary key
#  block_key    :string
#  description  :string
#  external_url :string
#  file_size    :integer
#  folder       :string
#  image        :string
#  sort_order   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  content_id   :integer
#
# Indexes
#
#  index_pwb_content_photos_on_content_id  (content_id)
#
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
