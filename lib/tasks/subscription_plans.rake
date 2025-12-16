# frozen_string_literal: true

namespace :pwb do
  namespace :plans do
    desc "Seed default subscription plans"
    task seed: :environment do
      require Rails.root.join('db/seeds/plans_seeds.rb')

      puts "\n" + "=" * 50
      puts "Seeding Subscription Plans"
      puts "=" * 50

      Pwb::PlansSeeder.seed!

      puts "\n" + "=" * 50
    end

    desc "List all subscription plans"
    task list: :environment do
      puts "\nSubscription Plans:"
      puts "=" * 60

      plans = Pwb::Plan.ordered

      if plans.empty?
        puts "\nNo plans found. Run 'rails pwb:plans:seed' to create default plans."
      else
        plans.each do |plan|
          status = []
          status << "INACTIVE" unless plan.active?
          status << "PRIVATE" unless plan.public?
          status_str = status.any? ? " [#{status.join(', ')}]" : ""

          puts "\n#{plan.display_name} (#{plan.slug})#{status_str}"
          puts "  Price: #{plan.formatted_price}"
          puts "  Billing: #{plan.billing_interval}ly"
          puts "  Trial: #{plan.trial_days} days"
          puts "  Properties: #{plan.property_limit || 'Unlimited'}"
          puts "  Users: #{plan.user_limit || 'Unlimited'}"
          puts "  Features: #{plan.features.join(', ')}" if plan.features.any?
          puts "  Subscriptions: #{plan.subscriptions.count}"
        end

        puts "\n" + "-" * 60
        puts "Total: #{plans.count} plans (#{Pwb::Plan.active.count} active, #{Pwb::Plan.public_plans.count} public)"
      end

      puts "=" * 60
    end

    desc "Show plan statistics"
    task stats: :environment do
      puts "\nSubscription Plan Statistics:"
      puts "=" * 60

      total_plans = Pwb::Plan.count
      active_plans = Pwb::Plan.active.count
      public_plans = Pwb::Plan.public_plans.count

      total_subscriptions = Pwb::Subscription.count
      active_subscriptions = Pwb::Subscription.active_subscriptions.count
      trialing_subscriptions = Pwb::Subscription.trialing.count
      past_due_subscriptions = Pwb::Subscription.past_due.count
      canceled_subscriptions = Pwb::Subscription.canceled.count

      puts "\nPlans:"
      puts "  Total: #{total_plans}"
      puts "  Active: #{active_plans}"
      puts "  Public: #{public_plans}"

      puts "\nSubscriptions:"
      puts "  Total: #{total_subscriptions}"
      puts "  Active: #{active_subscriptions}"
      puts "  Trialing: #{trialing_subscriptions}"
      puts "  Past Due: #{past_due_subscriptions}"
      puts "  Canceled: #{canceled_subscriptions}"

      if Pwb::Plan.any?
        puts "\nSubscriptions by Plan:"
        Pwb::Plan.ordered.each do |plan|
          count = plan.subscriptions.count
          active = plan.subscriptions.active_subscriptions.count
          puts "  #{plan.display_name}: #{count} total (#{active} active)"
        end
      end

      # Revenue estimation (if all subscriptions were active)
      if Pwb::Subscription.any?
        monthly_mrr = Pwb::Subscription.active_subscriptions.includes(:plan).sum do |sub|
          sub.plan.monthly_price_cents
        end
        puts "\nEstimated MRR: $#{(monthly_mrr / 100.0).round(2)}"
      end

      puts "=" * 60
    end

    desc "Reset all plans (WARNING: removes existing plans without subscriptions)"
    task reset: :environment do
      require Rails.root.join('db/seeds/plans_seeds.rb')

      plans_with_subscriptions = Pwb::Plan.joins(:subscriptions).distinct.count

      if plans_with_subscriptions > 0
        puts "\n*** WARNING ***"
        puts "#{plans_with_subscriptions} plan(s) have active subscriptions."
        puts "Only plans without subscriptions will be removed."
        puts "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
        sleep 5
      end

      puts "\n" + "=" * 50
      puts "Resetting Subscription Plans"
      puts "=" * 50

      # Only destroy plans without subscriptions
      Pwb::Plan.left_joins(:subscriptions)
               .where(pwb_subscriptions: { id: nil })
               .destroy_all

      puts "Removed plans without subscriptions."

      Pwb::PlansSeeder.seed!

      puts "\n" + "=" * 50
    end

    desc "Create a custom plan interactively"
    task create: :environment do
      puts "\nCreate a New Subscription Plan"
      puts "=" * 50

      print "Plan name (slug, e.g., 'basic'): "
      name = $stdin.gets.chomp.downcase.gsub(/\s+/, '_')

      if name.blank?
        puts "Error: Name is required"
        exit 1
      end

      if Pwb::Plan.exists?(name: name)
        puts "Error: Plan with name '#{name}' already exists"
        exit 1
      end

      print "Display name (e.g., 'Basic Plan'): "
      display_name = $stdin.gets.chomp
      display_name = name.titleize if display_name.blank?

      print "Description: "
      description = $stdin.gets.chomp

      print "Monthly price in cents (e.g., 2900 for $29): "
      price_cents = $stdin.gets.chomp.to_i

      print "Billing interval (month/year) [month]: "
      billing_interval = $stdin.gets.chomp
      billing_interval = 'month' if billing_interval.blank?

      print "Trial days [14]: "
      trial_days = $stdin.gets.chomp
      trial_days = trial_days.blank? ? 14 : trial_days.to_i

      print "Property limit (blank for unlimited): "
      property_limit = $stdin.gets.chomp
      property_limit = property_limit.blank? ? nil : property_limit.to_i

      print "User limit (blank for unlimited): "
      user_limit = $stdin.gets.chomp
      user_limit = user_limit.blank? ? nil : user_limit.to_i

      puts "\nAvailable features: #{Pwb::Plan::FEATURES.keys.join(', ')}"
      print "Features (comma-separated): "
      features = $stdin.gets.chomp.split(',').map(&:strip)

      print "Make this plan public? (y/n) [y]: "
      is_public = $stdin.gets.chomp.downcase != 'n'

      plan = Pwb::Plan.new(
        name: name,
        slug: name.gsub('_', '-'),
        display_name: display_name,
        description: description,
        price_cents: price_cents,
        price_currency: 'USD',
        billing_interval: billing_interval,
        trial_days: trial_days,
        property_limit: property_limit,
        user_limit: user_limit,
        features: features,
        active: true,
        public: is_public,
        position: Pwb::Plan.maximum(:position).to_i + 1
      )

      puts "\n" + "-" * 50
      puts "Plan Preview:"
      puts "  Name: #{plan.name}"
      puts "  Display Name: #{plan.display_name}"
      puts "  Price: #{plan.formatted_price}"
      puts "  Trial: #{plan.trial_days} days"
      puts "  Properties: #{plan.property_limit || 'Unlimited'}"
      puts "  Users: #{plan.user_limit || 'Unlimited'}"
      puts "  Features: #{plan.features.join(', ')}"
      puts "  Public: #{plan.public?}"
      puts "-" * 50

      print "\nCreate this plan? (y/n): "
      if $stdin.gets.chomp.downcase == 'y'
        if plan.save
          puts "\nPlan '#{plan.display_name}' created successfully!"
        else
          puts "\nError creating plan: #{plan.errors.full_messages.join(', ')}"
        end
      else
        puts "\nPlan creation cancelled."
      end
    end

    desc "Deactivate a plan"
    task :deactivate, [:plan_slug] => :environment do |_t, args|
      slug = args[:plan_slug]

      if slug.blank?
        puts "Usage: rails pwb:plans:deactivate[plan-slug]"
        puts "Run 'rails pwb:plans:list' to see available plans"
        exit 1
      end

      plan = Pwb::Plan.find_by(slug: slug)

      if plan.nil?
        puts "Error: Plan '#{slug}' not found"
        exit 1
      end

      if plan.subscriptions.active_or_trialing.any?
        puts "Warning: This plan has #{plan.subscriptions.active_or_trialing.count} active/trialing subscriptions."
        puts "Deactivating will prevent new subscriptions but existing ones will continue."
        print "Continue? (y/n): "
        exit 1 unless $stdin.gets.chomp.downcase == 'y'
      end

      plan.update!(active: false)
      puts "Plan '#{plan.display_name}' has been deactivated."
    end

    desc "Activate a plan"
    task :activate, [:plan_slug] => :environment do |_t, args|
      slug = args[:plan_slug]

      if slug.blank?
        puts "Usage: rails pwb:plans:activate[plan-slug]"
        exit 1
      end

      plan = Pwb::Plan.find_by(slug: slug)

      if plan.nil?
        puts "Error: Plan '#{slug}' not found"
        exit 1
      end

      plan.update!(active: true)
      puts "Plan '#{plan.display_name}' has been activated."
    end

    desc "Expire all trials that have ended"
    task expire_trials: :environment do
      puts "\nExpiring ended trials..."
      puts "=" * 50

      expired_count = 0
      Pwb::Subscription.trial_expired.find_each do |subscription|
        if subscription.may_expire_trial?
          subscription.expire_trial!
          puts "  Expired: #{subscription.website.subdomain}"
          expired_count += 1
        end
      end

      if expired_count > 0
        puts "\nExpired #{expired_count} trial subscription(s)."
      else
        puts "\nNo expired trials found."
      end

      puts "=" * 50
    end

    desc "List trials expiring soon (default: 7 days)"
    task :expiring_trials, [:days] => :environment do |_t, args|
      days = (args[:days] || 7).to_i

      puts "\nTrials Expiring Within #{days} Days:"
      puts "=" * 60

      expiring = Pwb::Subscription.trialing.expiring_soon(days).includes(:website, :plan)

      if expiring.empty?
        puts "\nNo trials expiring within #{days} days."
      else
        expiring.order(:trial_ends_at).each do |subscription|
          remaining = subscription.trial_days_remaining
          puts "\n#{subscription.website.subdomain}"
          puts "  Plan: #{subscription.plan.display_name}"
          puts "  Expires: #{subscription.trial_ends_at.strftime('%Y-%m-%d %H:%M')}"
          puts "  Days remaining: #{remaining}"
        end

        puts "\n" + "-" * 60
        puts "Total: #{expiring.count} trial(s) expiring soon"
      end

      puts "=" * 60
    end
  end
end
