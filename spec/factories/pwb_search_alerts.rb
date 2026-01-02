# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_search_alert, class: "Pwb::SearchAlert", aliases: [:search_alert] do
    association :saved_search, factory: :pwb_saved_search
    new_properties { [{ reference: "REF001", title: "Villa 1" }, { reference: "REF002", title: "Villa 2" }] }
    properties_count { 2 }

    trait :delivered do
      delivered_at { 1.hour.ago }
      sent_at { 2.hours.ago }
      email_status { "delivered" }
    end

    trait :sent do
      sent_at { 1.hour.ago }
      email_status { "sent" }
    end

    trait :failed do
      email_status { "failed" }
      error_message { "SMTP connection timeout" }
    end

    trait :with_many_properties do
      new_properties { (1..10).map { |n| { reference: "REF#{n.to_s.rjust(6, '0')}", title: "Property #{n}" } } }
      properties_count { 10 }
    end
  end
end
