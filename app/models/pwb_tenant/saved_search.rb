# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_saved_searches
#
#  id                 :bigint           not null, primary key
#  alert_frequency    :integer          default("none"), not null
#  email              :string           not null
#  email_verified     :boolean          default(FALSE), not null
#  enabled            :boolean          default(TRUE), not null
#  last_result_count  :integer          default(0)
#  last_run_at        :datetime
#  manage_token       :string           not null
#  name               :string
#  search_criteria    :jsonb            not null
#  seen_property_refs :jsonb            not null
#  unsubscribe_token  :string           not null
#  verification_token :string
#  verified_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :bigint           not null
#
# Indexes
#
#  index_pwb_saved_searches_on_email                 (email)
#  index_pwb_saved_searches_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_searches_on_unsubscribe_token     (unsubscribe_token) UNIQUE
#  index_pwb_saved_searches_on_verification_token    (verification_token) UNIQUE
#  index_pwb_saved_searches_on_website_id            (website_id)
#  index_pwb_saved_searches_on_website_id_and_email  (website_id,email)
#  index_saved_searches_for_alerts                   (website_id,enabled,alert_frequency)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
module PwbTenant
  class SavedSearch < Pwb::SavedSearch
    # Automatically scoped to current_website via acts_as_tenant
    acts_as_tenant :website, class_name: "Pwb::Website"
  end
end
