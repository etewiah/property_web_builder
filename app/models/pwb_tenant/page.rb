# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Page.
  # Inherits all functionality from Pwb::Page but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Page for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_pages
#
#  id                      :integer          not null, primary key
#  details                 :json
#  flags                   :integer          default(0), not null
#  meta_description        :text
#  seo_title               :string
#  show_in_footer          :boolean          default(FALSE)
#  show_in_top_nav         :boolean          default(FALSE)
#  slug                    :string
#  sort_order_footer       :integer          default(0)
#  sort_order_top_nav      :integer          default(0)
#  translations            :jsonb            not null
#  visible                 :boolean          default(FALSE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  last_updated_by_user_id :integer
#  setup_id                :string
#  website_id              :integer
#
# Indexes
#
#  index_pwb_pages_on_flags                (flags)
#  index_pwb_pages_on_show_in_footer       (show_in_footer)
#  index_pwb_pages_on_show_in_top_nav      (show_in_top_nav)
#  index_pwb_pages_on_slug_and_website_id  (slug,website_id) UNIQUE
#  index_pwb_pages_on_translations         (translations) USING gin
#  index_pwb_pages_on_website_id           (website_id)
#
  #
  class Page < Pwb::Page
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
