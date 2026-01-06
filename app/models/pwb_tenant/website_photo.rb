# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of WebsitePhoto.
  # Inherits all functionality from Pwb::WebsitePhoto but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::WebsitePhoto for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_website_photos
# Database name: primary
#
#  id           :bigint           not null, primary key
#  description  :string
#  external_url :string
#  file_size    :integer
#  folder       :string           default("weebrix")
#  image        :string
#  photo_key    :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  website_id   :bigint
#
# Indexes
#
#  index_pwb_website_photos_on_photo_key   (photo_key)
#  index_pwb_website_photos_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  class WebsitePhoto < Pwb::WebsitePhoto
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
