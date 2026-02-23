# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Contact.
  # Inherits all functionality from Pwb::Contact but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Contact for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_contacts
# Database name: primary
#
#  id                    :bigint           not null, primary key
#  details               :json
#  documentation_type    :integer
#  fax                   :string
#  first_name            :string
#  flags                 :integer          default(0), not null
#  last_name             :string
#  nationality           :string
#  other_email           :string
#  other_names           :string
#  other_phone_number    :string
#  primary_email         :string
#  primary_phone_number  :string
#  title                 :integer          default("mr")
#  unread_messages_count :integer          default(0), not null
#  website_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  documentation_id      :string
#  facebook_id           :string
#  linkedin_id           :string
#  primary_address_id    :integer
#  secondary_address_id  :integer
#  skype_id              :string
#  twitter_id            :string
#  user_id               :integer
#  website_id            :bigint
#
# Indexes
#
#  index_pwb_contacts_on_documentation_id          (documentation_id)
#  index_pwb_contacts_on_first_name                (first_name)
#  index_pwb_contacts_on_first_name_and_last_name  (first_name,last_name)
#  index_pwb_contacts_on_last_name                 (last_name)
#  index_pwb_contacts_on_primary_email             (primary_email)
#  index_pwb_contacts_on_primary_phone_number      (primary_phone_number)
#  index_pwb_contacts_on_title                     (title)
#  index_pwb_contacts_on_website_id                (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  class Contact < Pwb::Contact
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
