# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_search_alerts
#
#  id                  :bigint           not null, primary key
#  clicked_at          :datetime
#  delivered_at        :datetime
#  email_status        :string
#  error_message       :text
#  new_properties      :jsonb            not null
#  opened_at           :datetime
#  properties_count    :integer          default(0), not null
#  sent_at             :datetime
#  total_results_count :integer          default(0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  saved_search_id     :bigint           not null
#
# Indexes
#
#  index_pwb_search_alerts_on_saved_search_id                 (saved_search_id)
#  index_pwb_search_alerts_on_saved_search_id_and_created_at  (saved_search_id,created_at)
#  index_pwb_search_alerts_on_sent_at                         (sent_at)
#
# Foreign Keys
#
#  fk_rails_...  (saved_search_id => pwb_saved_searches.id)
#
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
