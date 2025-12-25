# frozen_string_literal: true

module SiteAdmin
  # BillingController
  # Shows subscription and billing information for the current website
  class BillingController < SiteAdminController
    def show
      @subscription = current_website.subscription
      @plan = @subscription&.plan
      @usage = calculate_usage
    end

    private

    def calculate_usage
      {
        properties: {
          current: current_website.realty_assets.count,
          limit: @plan&.property_limit,
          unlimited: @plan&.unlimited_properties?
        },
        users: {
          current: current_website.users.count,
          limit: @plan&.user_limit,
          unlimited: @plan&.unlimited_users?
        }
      }
    end
  end
end
