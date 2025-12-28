# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Message.
  # Inherits all functionality from Pwb::Message but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Message for console work or cross-tenant operations.
# == Schema Information
#
# Table name: pwb_messages
#
#  id               :integer          not null, primary key
#  content          :text
#  delivered_at     :datetime
#  delivery_email   :string
#  delivery_error   :text
#  delivery_success :boolean          default(FALSE)
#  host             :string
#  latitude         :float
#  locale           :string
#  longitude        :float
#  origin_email     :string
#  origin_ip        :string
#  read             :boolean          default(FALSE), not null
#  title            :string
#  url              :string
#  user_agent       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  client_id        :integer
#  contact_id       :integer
#  website_id       :bigint
#
# Indexes
#
#  index_pwb_messages_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  class Message < Pwb::Message
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
