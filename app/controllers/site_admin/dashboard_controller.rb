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

      # Subscription information for current website
      @subscription = Pwb::Subscription.find_by(website_id: website_id)
      if @subscription
        @subscription_info = {
          status: @subscription.status,
          plan_name: @subscription.plan.display_name,
          plan_price: @subscription.plan.formatted_price,
          trial_days_remaining: @subscription.trial_days_remaining,
          trial_ending_soon: @subscription.trial_ending_soon?,
          in_good_standing: @subscription.in_good_standing?,
          current_period_ends_at: @subscription.current_period_ends_at,
          property_limit: @subscription.plan.property_limit,
          remaining_properties: @subscription.remaining_properties,
          features: @subscription.plan.enabled_features
        }
      end
    end
  end
end
