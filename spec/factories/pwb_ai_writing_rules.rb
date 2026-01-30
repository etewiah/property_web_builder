# frozen_string_literal: true

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
