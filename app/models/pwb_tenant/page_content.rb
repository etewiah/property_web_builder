# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of PageContent.
  # Inherits all functionality from Pwb::PageContent but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::PageContent for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_page_contents
# Database name: primary
#
#  id              :bigint           not null, primary key
#  is_rails_part   :boolean          default(FALSE)
#  label           :string
#  page_part_key   :string
#  sort_order      :integer
#  visible_on_page :boolean          default(TRUE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_id      :bigint
#  page_id         :bigint
#  website_id      :bigint
#
# Indexes
#
#  index_pwb_page_contents_on_content_id  (content_id)
#  index_pwb_page_contents_on_page_id     (page_id)
#  index_pwb_page_contents_on_website_id  (website_id)
#
  class PageContent < Pwb::PageContent
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
