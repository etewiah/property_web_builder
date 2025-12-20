# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of PagePart.
  # Inherits all functionality from Pwb::PagePart but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::PagePart for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_page_parts
#
#  id              :bigint           not null, primary key
#  block_contents  :json
#  editor_setup    :json
#  flags           :integer          default(0), not null
#  is_rails_part   :boolean          default(FALSE)
#  locale          :string
#  order_in_editor :integer
#  page_part_key   :string
#  page_slug       :string
#  show_in_editor  :boolean          default(TRUE)
#  template        :text
#  theme_name      :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  website_id      :integer
#
# Indexes
#
#  index_page_parts_unique_per_website    (page_part_key,page_slug,website_id) UNIQUE
#  index_pwb_page_parts_on_page_part_key  (page_part_key)
#  index_pwb_page_parts_on_page_slug      (page_slug)
#  index_pwb_page_parts_on_website_id     (website_id)
#
  #
  class PagePart < Pwb::PagePart
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
