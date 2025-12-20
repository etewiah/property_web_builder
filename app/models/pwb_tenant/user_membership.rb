# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of UserMembership.
  # Inherits all functionality from Pwb::UserMembership but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::UserMembership for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_user_memberships
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  role       :string           default("member"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_user_memberships_on_user_id       (user_id)
#  index_pwb_user_memberships_on_website_id    (website_id)
#  index_user_memberships_on_user_and_website  (user_id,website_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
  #
  class UserMembership < Pwb::UserMembership
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
