# frozen_string_literal: true

module PwbTenant
  class SupportTicket < Pwb::SupportTicket
    # Automatically scoped to current_website via acts_as_tenant
  end
end
