# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_testimonials
#
#  id              :bigint           not null, primary key
#  author_name     :string           not null
#  author_role     :string
#  quote           :text             not null
#  rating          :integer
#  position        :integer          default(0), not null
#  visible         :boolean          default(TRUE), not null
#  featured        :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  website_id      :integer          not null
#  author_photo_id :integer
#
# Indexes
#
#  index_pwb_testimonials_on_website_id      (website_id)
#  index_pwb_testimonials_on_visible         (visible)
#  index_pwb_testimonials_on_position        (position)
#  index_pwb_testimonials_on_author_photo_id (author_photo_id)
#
FactoryBot.define do
  factory :pwb_testimonial, class: 'Pwb::Testimonial' do
    association :website, factory: :pwb_website
    
    sequence(:author_name) { |n| "Customer #{n}" }
    author_role { "Property Buyer" }
    quote { "Excellent service! Highly recommend to anyone looking for a property." }
    rating { 5 }
    sequence(:position) { |n| n }
    visible { true }
    featured { false }

    trait :featured do
      featured { true }
    end

    trait :hidden do
      visible { false }
    end

    trait :with_photo do
      association :author_photo, factory: :pwb_media
    end
  end
end
