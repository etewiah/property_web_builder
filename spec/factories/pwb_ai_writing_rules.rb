# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_ai_writing_rules
# Database name: primary
#
#  id           :bigint           not null, primary key
#  active       :boolean          default(TRUE)
#  description  :text
#  name         :string           not null
#  position     :integer          default(0)
#  rule_content :text             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  website_id   :bigint           not null
#
# Indexes
#
#  index_pwb_ai_writing_rules_on_website_id             (website_id)
#  index_pwb_ai_writing_rules_on_website_id_and_active  (website_id,active)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_ai_writing_rule, class: 'Pwb::AiWritingRule' do
    association :website, factory: :pwb_website

    sequence(:name) { |n| "Writing Rule #{n}" }
    rule_content { 'Always be concise and professional.' }
    active { true }
    position { 0 }

    trait :inactive do
      active { false }
    end

    trait :british_english do
      name { 'British English' }
      rule_content { 'Always use British English spelling (colour, centre, realise).' }
    end

    trait :no_superlatives do
      name { 'Avoid Superlatives' }
      rule_content { 'Avoid superlatives like "best", "amazing", "perfect". Use specific facts instead.' }
    end

    trait :mention_transport do
      name { 'Public Transport' }
      rule_content { 'Always mention proximity to public transport when known.' }
    end

    trait :formal_tone do
      name { 'Formal Tone' }
      rule_content { 'Maintain a formal, professional tone throughout.' }
    end
  end
end
