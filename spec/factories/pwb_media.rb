# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_media
#
#  id           :bigint           not null, primary key
#  alt_text     :string
#  byte_size    :bigint
#  caption      :string
#  checksum     :string
#  content_type :string
#  description  :text
#  filename     :string           not null
#  height       :integer
#  last_used_at :datetime
#  sort_order   :integer          default(0)
#  source_type  :string
#  source_url   :string
#  tags         :string           default([]), is an Array
#  title        :string
#  usage_count  :integer          default(0)
#  width        :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  folder_id    :bigint
#  website_id   :bigint           not null
#
# Indexes
#
#  index_pwb_media_on_folder_id                    (folder_id)
#  index_pwb_media_on_tags                         (tags) USING gin
#  index_pwb_media_on_website_id                   (website_id)
#  index_pwb_media_on_website_id_and_content_type  (website_id,content_type)
#  index_pwb_media_on_website_id_and_created_at    (website_id,created_at)
#  index_pwb_media_on_website_id_and_folder_id     (website_id,folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (folder_id => pwb_media_folders.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_media, class: 'Pwb::Media' do
    association :website, factory: :pwb_website
    sequence(:filename) { |n| "test_image_#{n}.jpg" }
    content_type { 'image/jpeg' }
    byte_size { 1024 }
    source_type { 'upload' }

    after(:build) do |media|
      # Attach a minimal file blob for testing
      media.file.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9"),
        filename: media.filename,
        content_type: media.content_type
      )
    end

    trait :with_folder do
      association :folder, factory: :pwb_media_folder
    end

    trait :with_metadata do
      title { 'Test Image Title' }
      alt_text { 'A test image for automated testing' }
      description { 'This is a detailed description of the test image.' }
      caption { 'Test image caption' }
    end

    trait :with_dimensions do
      width { 800 }
      height { 600 }
    end

    trait :pdf do
      sequence(:filename) { |n| "document_#{n}.pdf" }
      content_type { 'application/pdf' }

      after(:build) do |media|
        media.file.attach(
          io: StringIO.new('%PDF-1.4'),
          filename: media.filename,
          content_type: media.content_type
        )
      end
    end

    trait :png do
      sequence(:filename) { |n| "image_#{n}.png" }
      content_type { 'image/png' }

      after(:build) do |media|
        # Minimal PNG file
        png_data = "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xDE"
        media.file.attach(
          io: StringIO.new(png_data),
          filename: media.filename,
          content_type: media.content_type
        )
      end
    end

    trait :with_tags do
      tags { %w[property exterior featured] }
    end

    trait :used do
      usage_count { 5 }
      last_used_at { 1.day.ago }
    end
  end
end
