# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_search_alerts
# Database name: primary
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
module PwbTenant
  class SearchAlert < Pwb::SearchAlert
    # Note: SearchAlert belongs to SavedSearch, not directly to Website
    # Scoping happens through the saved_search association
  end
end
