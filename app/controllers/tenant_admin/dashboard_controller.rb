# frozen_string_literal: true

module TenantAdmin
  class DashboardController < TenantAdminController
    def index
      # System overview statistics
      @total_websites = Pwb::Website.unscoped.count
      @total_users = Pwb::User.unscoped.count
      @total_properties = Pwb::Prop.unscoped.count
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
      
      @recent_properties = Pwb::Prop.unscoped
                                     .order(created_at: :desc)
                                     .limit(10)
    end
  end
end
