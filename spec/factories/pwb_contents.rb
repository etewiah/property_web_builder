# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_contents
#
#  id                      :integer          not null, primary key
#  input_type              :string
#  key                     :string
#  page_part_key           :string
#  section_key             :string
#  sort_order              :integer
#  status                  :string
#  tag                     :string
#  target_url              :string
#  translations            :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  last_updated_by_user_id :integer
#  website_id              :integer
#
# Indexes
#
#  index_pwb_contents_on_translations        (translations) USING gin
#  index_pwb_contents_on_website_id          (website_id)
#  index_pwb_contents_on_website_id_and_key  (website_id,key) UNIQUE
#
FactoryBot.define do
  factory :pwb_content, class: 'PwbTenant::Content' do
    key { "MyString" }
    tag { "MyString" }
    raw { "MyText" }
    website { Pwb::Website.first || association(:pwb_website) }

    trait :main_content do
      raw_en { "<h2>Sell Your Property with Us</h2>" }
    end
  end
end
