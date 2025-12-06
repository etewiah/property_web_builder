# frozen_string_literal: true

module Pwb
  # Message represents messages/inquiries from website visitors.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Message for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class Message < ApplicationRecord
    self.table_name = 'pwb_messages'

    belongs_to :website, class_name: 'Pwb::Website', optional: true
    belongs_to :contact, optional: true, class_name: 'Pwb::Contact'
  end
end
