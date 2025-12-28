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
        price_cents: 1000,
        price_currency: 'USD',
        billing_interval: 'month',
        trial_days: 30,
        property_limit: 5,
        user_limit: 1,
        features: %w[basic_themes ssl_included email_support],
        position: 1
      },
      {
        name: 'professional',
        slug: 'professional',
        display_name: 'Professional',
        description: 'For growing agencies that need more properties and features.',
        price_cents: 9900,
        price_currency: 'USD',
        billing_interval: 'month',
        trial_days: 30,
        property_limit: 100,
        user_limit: 5,
        features: %w[basic_themes premium_themes analytics custom_domain multi_language priority_support],
        position: 2
      },
      {
        name: 'enterprise',
        slug: 'enterprise',
        display_name: 'Enterprise',
        description: 'Unlimited properties and all features for large agencies.',
        price_cents: 74900,
        price_currency: 'USD',
        billing_interval: 'month',
        trial_days: 30,
        property_limit: nil, # Unlimited
        user_limit: nil,     # Unlimited
        features: %w[basic_themes premium_themes analytics custom_domain api_access white_label dedicated_support all_languages],
        position: 3
      },
      # Annual plans (20% discount)
      {
        name: 'starter_annual',
        slug: 'starter-annual',
        display_name: 'Starter (Annual)',
        description: 'Starter plan billed annually - save 20%!',
        price_cents: 9600, # $96/year = $8/month (20% off $10/month)
        price_currency: 'USD',
        billing_interval: 'year',
        trial_days: 30,
        property_limit: 5,
        user_limit: 1,
        features: %w[basic_themes ssl_included email_support],
        position: 4,
        public: false # Don't show on main pricing page, offer as upgrade
      },
      {
        name: 'professional_annual',
        slug: 'professional-annual',
        display_name: 'Professional (Annual)',
        description: 'Professional plan billed annually - save 20%!',
        price_cents: 95040, # $950.40/year = $79.20/month (20% off $99/month)
        price_currency: 'USD',
        billing_interval: 'year',
        trial_days: 30,
        property_limit: 100,
        user_limit: 5,
        features: %w[basic_themes premium_themes analytics custom_domain multi_language priority_support],
        position: 5,
        public: false
      },
      {
        name: 'enterprise_annual',
        slug: 'enterprise-annual',
        display_name: 'Enterprise (Annual)',
        description: 'Enterprise plan billed annually - save 20%!',
        price_cents: 719040, # $7190.40/year = $599.20/month (20% off $749/month)
        price_currency: 'USD',
        billing_interval: 'year',
        trial_days: 30,
        property_limit: nil,
        user_limit: nil,
        features: %w[basic_themes premium_themes analytics custom_domain api_access white_label dedicated_support all_languages],
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
