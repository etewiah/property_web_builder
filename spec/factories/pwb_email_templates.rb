# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_email_templates
# Database name: primary
#
#  id           :bigint           not null, primary key
#  active       :boolean          default(TRUE), not null
#  body_html    :text             not null
#  body_text    :text
#  description  :text
#  name         :string           not null
#  subject      :string           not null
#  template_key :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  website_id   :bigint           not null
#
# Indexes
#
#  index_pwb_email_templates_on_active                       (active)
#  index_pwb_email_templates_on_template_key                 (template_key)
#  index_pwb_email_templates_on_website_id                   (website_id)
#  index_pwb_email_templates_on_website_id_and_template_key  (website_id,template_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_email_template, class: 'Pwb::EmailTemplate' do
    association :website, factory: :pwb_website
    template_key { 'enquiry.general' }
    name { 'Custom General Enquiry' }
    subject { 'New enquiry from {{ visitor_name }}' }
    body_html { '<p>Hello, {{ visitor_name }} sent a message: {{ message }}</p>' }
    body_text { 'Hello, {{ visitor_name }} sent a message: {{ message }}' }
    description { 'Custom template for general enquiries' }
    active { true }

    trait :property_enquiry do
      template_key { 'enquiry.property' }
      name { 'Custom Property Enquiry' }
      subject { 'Enquiry about {{ property_title }}' }
      body_html { '<p>{{ visitor_name }} is interested in {{ property_title }}</p>' }
      body_text { '{{ visitor_name }} is interested in {{ property_title }}' }
      description { 'Custom template for property enquiries' }
    end

    trait :auto_reply do
      template_key { 'enquiry.auto_reply' }
      name { 'Enquiry Auto-Reply' }
      subject { 'Thank you for contacting us' }
      body_html { '<p>Dear {{ visitor_name }}, thank you for your enquiry.</p>' }
      body_text { 'Dear {{ visitor_name }}, thank you for your enquiry.' }
      description { 'Auto-reply sent to visitors after enquiry' }
    end

    trait :inactive do
      active { false }
    end
  end
end
