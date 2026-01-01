# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_ticket_messages
#
#  id                  :uuid             not null, primary key
#  content             :text             not null
#  from_platform_admin :boolean          default(FALSE)
#  internal_note       :boolean          default(FALSE)
#  status_changed_from :string(50)
#  status_changed_to   :string(50)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  support_ticket_id   :uuid             not null
#  user_id             :bigint           not null
#  website_id          :bigint           not null
#
FactoryBot.define do
  factory :pwb_ticket_message, class: 'Pwb::TicketMessage', aliases: [:ticket_message] do
    support_ticket { association(:pwb_support_ticket) }
    website { support_ticket.website }
    user { support_ticket.creator }
    content { "This is a reply to the support ticket." }
    from_platform_admin { false }
    internal_note { false }

    trait :from_platform do
      from_platform_admin { true }
      content { "Platform support team response." }
    end

    trait :internal_note do
      internal_note { true }
      from_platform_admin { true }
      content { "Internal note: This is for platform team only." }
    end

    trait :with_status_change do
      status_changed_from { 'open' }
      status_changed_to { 'in_progress' }
    end
  end
end
