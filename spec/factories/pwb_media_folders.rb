# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_media_folder, class: 'Pwb::MediaFolder' do
    association :website, factory: :pwb_website
    sequence(:name) { |n| "Folder #{n}" }

    trait :with_slug do
      sequence(:slug) { |n| "folder-#{n}" }
    end

    trait :nested do
      association :parent, factory: :pwb_media_folder
    end

    trait :with_media do
      after(:create) do |folder|
        create_list(:pwb_media, 3, website: folder.website, folder: folder)
      end
    end

    trait :with_children do
      after(:create) do |folder|
        create_list(:pwb_media_folder, 2, website: folder.website, parent: folder)
      end
    end

    trait :sorted do
      sequence(:sort_order) { |n| n }
    end
  end
end
