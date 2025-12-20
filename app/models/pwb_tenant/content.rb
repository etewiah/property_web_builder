# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Content.
  # Inherits all functionality from Pwb::Content but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Content for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_contents
#
#  id                      :integer          not null, primary key
#  input_type              :string
#  key                     :string
#  page_part_key           :string
#  section_key             :string
#  sort_order              :integer
#  status                  :string
#  tag                     :string
#  target_url              :string
#  translations            :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  last_updated_by_user_id :integer
#  website_id              :integer
#
# Indexes
#
#  index_pwb_contents_on_translations        (translations) USING gin
#  index_pwb_contents_on_website_id          (website_id)
#  index_pwb_contents_on_website_id_and_key  (website_id,key) UNIQUE
#
  #
  class Content < Pwb::Content
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
