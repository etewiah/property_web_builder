# frozen_string_literal: true

module TenantAdmin
  class DashboardController < TenantAdminController
    def index
      # System overview statistics
      # Use Pwb::ListedProperty (materialized view) for property counts
      @total_websites = Pwb::Website.unscoped.count
      @total_users = Pwb::User.unscoped.count
      @total_properties = Pwb::ListedProperty.count
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

      # Use Pwb::ListedProperty (materialized view) for property listing
      @recent_properties = Pwb::ListedProperty.order(created_at: :desc).limit(10)

      # Subscription statistics
      @subscription_stats = {
        total: Pwb::Subscription.count,
        active: Pwb::Subscription.active_subscriptions.count,
        trialing: Pwb::Subscription.trialing.count,
        past_due: Pwb::Subscription.past_due.count,
        canceled: Pwb::Subscription.canceled.count,
        expiring_soon: Pwb::Subscription.expiring_soon(7).count
      }

      # Plan statistics
      @plan_stats = {
        total: Pwb::Plan.count,
        active: Pwb::Plan.active.count
      }

      # Subscriptions expiring soon (trial ending within 7 days)
      @expiring_trials = Pwb::Subscription.trialing
                                          .expiring_soon(7)
                                          .includes(:website, :plan)
                                          .order(:trial_ends_at)
                                          .limit(5)
    end
  end
end
