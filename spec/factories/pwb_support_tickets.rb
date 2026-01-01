# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_support_tickets
#
#  id                   :uuid             not null, primary key
#  assigned_at          :datetime
#  category             :string(50)
#  closed_at            :datetime
#  description          :text
#  first_response_at    :datetime
#  last_customer_reply  :datetime
#  last_platform_reply  :datetime
#  message_count        :integer          default(0), not null
#  priority             :integer          default("normal"), not null
#  resolved_at          :datetime
#  status               :integer          default("open"), not null
#  subject              :string(255)      not null
#  ticket_number        :string(20)       not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  assigned_to_id       :bigint
#  creator_id           :bigint           not null
#  website_id           :bigint           not null
#
FactoryBot.define do
  factory :pwb_support_ticket, class: 'Pwb::SupportTicket', aliases: [:support_ticket] do
    website { Pwb::Website.first || association(:pwb_website) }
    creator { association(:pwb_user, website: website) }
    subject { "Test support ticket #{SecureRandom.hex(4)}" }
    description { "This is a test support ticket description with details about the issue." }
    category { Pwb::SupportTicket::CATEGORIES.sample }
    priority { :normal }
    status { :open }

    trait :billing do
      category { 'billing' }
      subject { 'Billing inquiry' }
    end

    trait :technical do
      category { 'technical' }
      subject { 'Technical issue with property listings' }
    end

    trait :urgent do
      priority { :urgent }
    end

    trait :high_priority do
      priority { :high }
    end

    trait :in_progress do
      status { :in_progress }
      assigned_to { association(:pwb_user, website: website) }
      assigned_at { Time.current }
    end

    trait :waiting_on_customer do
      status { :waiting_on_customer }
    end

    trait :resolved do
      status { :resolved }
      resolved_at { Time.current }
    end

    trait :closed do
      status { :closed }
      closed_at { Time.current }
    end

    trait :with_messages do
      transient do
        message_count { 3 }
      end

      after(:create) do |ticket, evaluator|
        evaluator.message_count.times do |i|
          create(:pwb_ticket_message,
                 support_ticket: ticket,
                 website: ticket.website,
                 user: i.even? ? ticket.creator : (ticket.assigned_to || ticket.creator),
                 from_platform_admin: i.odd?,
                 content: "Message #{i + 1} content")
        end
        ticket.reload
      end
    end
  end
end
