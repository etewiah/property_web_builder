# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_saved_properties
#
#  id                   :bigint           not null, primary key
#  current_price_cents  :integer
#  email                :string           not null
#  external_reference   :string           not null
#  manage_token         :string           not null
#  notes                :text
#  original_price_cents :integer
#  price_changed_at     :datetime
#  property_data        :jsonb            not null
#  provider             :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  website_id           :bigint           not null
#
# Indexes
#
#  index_pwb_saved_properties_on_email                 (email)
#  index_pwb_saved_properties_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_properties_on_website_id            (website_id)
#  index_pwb_saved_properties_on_website_id_and_email  (website_id,email)
#  index_saved_properties_on_provider_ref              (website_id,provider,external_reference)
#  index_saved_properties_unique_per_email             (email,provider,external_reference) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
module PwbTenant
  class SavedProperty < Pwb::SavedProperty
    # Automatically scoped to current_website via acts_as_tenant
    acts_as_tenant :website, class_name: "Pwb::Website"
  end
end
