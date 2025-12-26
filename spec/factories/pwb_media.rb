# frozen_string_literal: true

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
