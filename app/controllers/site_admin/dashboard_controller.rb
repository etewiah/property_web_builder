# frozen_string_literal: true

module SiteAdmin
  # DashboardController
  # Main dashboard for site administration
  # Shows statistics and recent activity for the current website/tenant
  class DashboardController < SiteAdminController
    def index
      @website = current_website

      # Statistics for current website
      # Use Pwb::Property (materialized view) for property counts
      @stats = {
        total_properties: Pwb::Property.count,
        total_pages: Pwb::Page.count,
        total_contents: Pwb::Content.count,
        total_messages: Pwb::Message.count,
        total_contacts: Pwb::Contact.count
      }

      # Recent activity for current website
      # Use Pwb::Property (materialized view) for property listing
      @recent_properties = Pwb::Property.order(created_at: :desc).limit(5)
      @recent_messages = Pwb::Message.order(created_at: :desc).limit(5)
      @recent_contacts = Pwb::Contact.order(created_at: :desc).limit(5)
    end
  end
end
