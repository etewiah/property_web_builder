# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Link.
  # Inherits all functionality from Pwb::Link but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Link for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_links
# Database name: primary
#
#  id               :integer          not null, primary key
#  flags            :integer          default(0), not null
#  href_class       :string
#  href_target      :string
#  icon_class       :string
#  is_deletable     :boolean          default(FALSE)
#  is_external      :boolean          default(FALSE)
#  link_path        :string
#  link_path_params :string
#  link_url         :string
#  page_slug        :string
#  parent_slug      :string
#  placement        :integer          default("top_nav")
#  slug             :string
#  sort_order       :integer          default(0)
#  translations     :jsonb            not null
#  visible          :boolean          default(TRUE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  website_id       :integer
#
# Indexes
#
#  index_pwb_links_on_flags                (flags)
#  index_pwb_links_on_page_slug            (page_slug)
#  index_pwb_links_on_placement            (placement)
#  index_pwb_links_on_translations         (translations) USING gin
#  index_pwb_links_on_website_id           (website_id)
#  index_pwb_links_on_website_id_and_slug  (website_id,slug) UNIQUE
#
  class Link < Pwb::Link
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
