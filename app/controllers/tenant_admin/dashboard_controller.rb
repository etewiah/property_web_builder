# frozen_string_literal: true

module TenantAdmin
  class DashboardController < TenantAdminController
    def index
      # System overview statistics
      # Use Pwb::Property (materialized view) for property counts
      @total_websites = Pwb::Website.unscoped.count
      @total_users = Pwb::User.unscoped.count
      @total_properties = Pwb::Property.count
      @active_tenants = Pwb::Website.unscoped
                                     .where('updated_at >= ?', 30.days.ago)
                                     .count

      # Recent activity
      @recent_websites = Pwb::Website.unscoped
                                      .order(created_at: :desc)
                                      .limit(5)

      @recent_users = Pwb::User.unscoped
                                .order(created_at: :desc)
                                .limit(10)

      @recent_messages = Pwb::Message.unscoped
                                      .order(created_at: :desc)
                                      .limit(10) rescue []

      # Use Pwb::Property (materialized view) for property listing
      @recent_properties = Pwb::Property.order(created_at: :desc).limit(10)
    end
  end
end
