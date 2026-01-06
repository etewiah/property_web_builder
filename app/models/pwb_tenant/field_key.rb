# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of FieldKey.
  # Inherits all functionality from Pwb::FieldKey but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::FieldKey for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_field_keys
# Database name: primary
#
#  id                  :integer          not null
#  global_key          :string           primary key
#  props_count         :integer          default(0), not null
#  show_in_search_form :boolean          default(TRUE)
#  sort_order          :integer          default(0)
#  tag                 :string
#  translations        :jsonb            not null
#  visible             :boolean          default(TRUE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  pwb_website_id      :bigint
#
# Indexes
#
#  index_field_keys_on_website_and_tag     (pwb_website_id,tag)
#  index_field_keys_unique_per_website     (pwb_website_id,global_key) UNIQUE
#  index_pwb_field_keys_on_pwb_website_id  (pwb_website_id)
#
# Foreign Keys
#
#  fk_rails_...  (pwb_website_id => pwb_websites.id)
#
  class FieldKey < Pwb::FieldKey
    include RequiresTenant
    acts_as_tenant :website, foreign_key: 'pwb_website_id', class_name: 'Pwb::Website'
  end
end
