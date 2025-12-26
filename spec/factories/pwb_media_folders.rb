# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_media_folders
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string
#  sort_order :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_media_folders_on_parent_id                 (parent_id)
#  index_pwb_media_folders_on_website_id                (website_id)
#  index_pwb_media_folders_on_website_id_and_parent_id  (website_id,parent_id)
#  index_pwb_media_folders_on_website_id_and_slug       (website_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => pwb_media_folders.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
