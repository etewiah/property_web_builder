# frozen_string_literal: true

module Pwb
  # Message represents messages/inquiries from website visitors.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Message for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
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
  class Message < ApplicationRecord
    self.table_name = 'pwb_messages'

    belongs_to :website, class_name: 'Pwb::Website', optional: true
    belongs_to :contact, optional: true, class_name: 'Pwb::Contact'
  end
end
