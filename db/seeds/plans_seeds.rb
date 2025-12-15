# frozen_string_literal: true

# Seed data for subscription plans
#
# Run with: rails runner "load 'db/seeds/plans_seeds.rb'"
# Or call: Pwb::PlansSeeder.seed!

module Pwb
  class PlansSeeder
    PLANS = [
      {
        name: 'starter',
        slug: 'starter',
        display_name: 'Starter',
        description: 'Perfect for getting started with your real estate website.',
        price_cents: 2900,
        price_currency: 'USD',
        billing_interval: 'month',
        trial_days: 14,
        property_limit: 25,
        user_limit: 2,
        features: %w[basic_themes],
        position: 1
      },
      {
        name: 'professional',
        slug: 'professional',
        display_name: 'Professional',
        description: 'For growing agencies that need more properties and features.',
        price_cents: 7900,
        price_currency: 'USD',
        billing_interval: 'month',
        trial_days: 14,
        property_limit: 100,
        user_limit: 5,
        features: %w[basic_themes premium_themes analytics custom_domain],
        position: 2
      },
      {
        name: 'enterprise',
        slug: 'enterprise',
        display_name: 'Enterprise',
        description: 'Unlimited properties and all features for large agencies.',
        price_cents: 19900,
        price_currency: 'USD',
        billing_interval: 'month',
        trial_days: 14,
        property_limit: nil, # Unlimited
        user_limit: nil,     # Unlimited
        features: %w[basic_themes premium_themes analytics custom_domain api_access white_label priority_support],
        position: 3
      },
      # Annual plans (discounted)
      {
        name: 'starter_annual',
        slug: 'starter-annual',
        display_name: 'Starter (Annual)',
        description: 'Starter plan billed annually - save 2 months!',
        price_cents: 29000, # ~$290/year = $24.17/month (2 months free)
        price_currency: 'USD',
        billing_interval: 'year',
        trial_days: 14,
        property_limit: 25,
        user_limit: 2,
        features: %w[basic_themes],
        position: 4,
        public: false # Don't show on main pricing page, offer as upgrade
      },
      {
        name: 'professional_annual',
        slug: 'professional-annual',
        display_name: 'Professional (Annual)',
        description: 'Professional plan billed annually - save 2 months!',
        price_cents: 79000, # ~$790/year = $65.83/month (2 months free)
        price_currency: 'USD',
        billing_interval: 'year',
        trial_days: 14,
        property_limit: 100,
        user_limit: 5,
        features: %w[basic_themes premium_themes analytics custom_domain],
        position: 5,
        public: false
      },
      {
        name: 'enterprise_annual',
        slug: 'enterprise-annual',
        display_name: 'Enterprise (Annual)',
        description: 'Enterprise plan billed annually - save 2 months!',
        price_cents: 199000, # ~$1990/year = $165.83/month (2 months free)
        price_currency: 'USD',
        billing_interval: 'year',
        trial_days: 14,
        property_limit: nil,
        user_limit: nil,
        features: %w[basic_themes premium_themes analytics custom_domain api_access white_label priority_support],
        position: 6,
        public: false
      }
    ].freeze

    class << self
      def seed!
        puts "Seeding subscription plans..."

        PLANS.each do |plan_data|
          plan = Pwb::Plan.find_or_initialize_by(slug: plan_data[:slug])

          plan.assign_attributes(plan_data)
          plan.public = plan_data.fetch(:public, true)

          if plan.new_record?
            plan.save!
            puts "  Created plan: #{plan.display_name} (#{plan.formatted_price})"
          elsif plan.changed?
            plan.save!
            puts "  Updated plan: #{plan.display_name}"
          else
            puts "  Plan exists: #{plan.display_name}"
          end
        end

        puts "Done! #{Pwb::Plan.count} plans available."
      end

      def reset!
        puts "Resetting all plans..."
        Pwb::Plan.destroy_all
        seed!
      end
    end
  end
end

# Auto-run if called directly
if __FILE__ == $PROGRAM_NAME
  Pwb::PlansSeeder.seed!
end
