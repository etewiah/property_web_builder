# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_links
#
#  id               :integer          not null, primary key
#  flags            :integer          default(0), not null
#  href_class       :string
#  href_target      :string
#  icon_class       :string
#  is_deletable     :boolean          default(FALSE)
#  is_external      :boolean          default(FALSE)
#  link_path        :string
#  link_path_params :string
#  link_url         :string
#  page_slug        :string
#  parent_slug      :string
#  placement        :integer          default("top_nav")
#  slug             :string
#  sort_order       :integer          default(0)
#  translations     :jsonb            not null
#  visible          :boolean          default(TRUE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  website_id       :integer
#
# Indexes
#
#  index_pwb_links_on_flags                (flags)
#  index_pwb_links_on_page_slug            (page_slug)
#  index_pwb_links_on_placement            (placement)
#  index_pwb_links_on_translations         (translations) USING gin
#  index_pwb_links_on_website_id           (website_id)
#  index_pwb_links_on_website_id_and_slug  (website_id,slug) UNIQUE
#
FactoryBot.define do
  factory :pwb_link, class: 'PwbTenant::Link' do
    association :website, factory: :pwb_website
    slug { SecureRandom.uuid }

    trait :top_nav do
      placement { :top_nav }
    end

    trait :footer do
      placement { :footer }
    end
  end
end
