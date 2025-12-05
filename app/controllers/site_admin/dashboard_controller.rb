# frozen_string_literal: true

module SiteAdmin
  # DashboardController
  # Main dashboard for site administration
  # Shows statistics and recent activity for the current website/tenant
  class DashboardController < SiteAdminController
    def index
      @website = current_website
      website_id = current_website&.id

      # Statistics for current website - scoped by website_id for multi-tenant isolation
      # Use Pwb::ListedProperty (materialized view) for property counts
      @stats = {
        total_properties: Pwb::ListedProperty.where(website_id: website_id).count,
        total_pages: Pwb::Page.where(website_id: website_id).count,
        total_contents: Pwb::Content.where(website_id: website_id).count,
        total_messages: Pwb::Message.where(website_id: website_id).count,
        total_contacts: Pwb::Contact.where(website_id: website_id).count
      }

      # Recent activity for current website - scoped by website_id for multi-tenant isolation
      # Use Pwb::ListedProperty (materialized view) for property listing
      @recent_properties = Pwb::ListedProperty.where(website_id: website_id).order(created_at: :desc).limit(5)
      @recent_messages = Pwb::Message.where(website_id: website_id).order(created_at: :desc).limit(5)
      @recent_contacts = Pwb::Contact.where(website_id: website_id).order(created_at: :desc).limit(5)
    end
  end
end
