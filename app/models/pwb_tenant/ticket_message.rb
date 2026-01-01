# frozen_string_literal: true

module PwbTenant
  class TicketMessage < Pwb::TicketMessage
    # Automatically scoped to current_website via acts_as_tenant
  end
end
