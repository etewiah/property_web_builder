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

  # ==========================================================================
  # Subscription Management Tasks
  # ==========================================================================
  namespace :subscriptions do
    desc "List all subscriptions"
    task list: :environment do
      puts "\nAll Subscriptions:"
      puts "=" * 70

      subscriptions = Pwb::Subscription.includes(:website, :plan).order(created_at: :desc)

      if subscriptions.empty?
        puts "\nNo subscriptions found."
      else
        subscriptions.each do |sub|
          status_color = case sub.status
                         when 'active' then 'active'
                         when 'trialing' then 'trialing'
                         when 'past_due' then 'PAST DUE'
                         when 'canceled' then 'canceled'
                         when 'expired' then 'EXPIRED'
                         else sub.status.upcase
                         end

          puts "\n#{sub.website&.subdomain || 'Unknown'} [#{status_color}]"
          puts "  Plan: #{sub.plan&.display_name || 'Unknown'}"
          puts "  Status: #{sub.status}"
          if sub.trialing?
            puts "  Trial ends: #{sub.trial_ends_at&.strftime('%Y-%m-%d')} (#{sub.trial_days_remaining} days left)"
          end
          puts "  Period: #{sub.current_period_starts_at&.strftime('%Y-%m-%d')} to #{sub.current_period_ends_at&.strftime('%Y-%m-%d')}"
          puts "  Cancel at period end: #{sub.cancel_at_period_end}" if sub.cancel_at_period_end
        end

        puts "\n" + "-" * 70
        puts "Total: #{subscriptions.count} subscription(s)"
      end

      puts "=" * 70
    end

    desc "Show subscription details for a website"
    task :show, [:subdomain] => :environment do |_t, args|
      subdomain = args[:subdomain]

      if subdomain.blank?
        puts "Usage: rails pwb:subscriptions:show[subdomain]"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)

      if website.nil?
        puts "Error: Website '#{subdomain}' not found"
        exit 1
      end

      subscription = website.subscription

      puts "\nSubscription for #{subdomain}:"
      puts "=" * 60

      if subscription.nil?
        puts "\nNo subscription found for this website."
        puts "\nTo create a subscription, run:"
        puts "  rails pwb:subscriptions:create[#{subdomain},plan-slug]"
      else
        service = Pwb::SubscriptionService.new
        status = service.status_for(website)

        puts "\nPlan: #{status[:plan_name]} (#{status[:plan_slug]})"
        puts "Status: #{status[:status]}"
        puts "Allows access: #{status[:allows_access]}"
        puts "In good standing: #{status[:in_good_standing]}"

        if subscription.trialing?
          puts "\nTrial:"
          puts "  Days remaining: #{status[:trial_days_remaining]}"
          puts "  Ends at: #{subscription.trial_ends_at&.strftime('%Y-%m-%d %H:%M')}"
          puts "  Ending soon: #{status[:trial_ending_soon]}"
        end

        puts "\nBilling Period:"
        puts "  Starts: #{subscription.current_period_starts_at&.strftime('%Y-%m-%d')}"
        puts "  Ends: #{subscription.current_period_ends_at&.strftime('%Y-%m-%d')}"
        puts "  Cancel at period end: #{subscription.cancel_at_period_end}"

        puts "\nLimits:"
        puts "  Property limit: #{status[:property_limit] || 'Unlimited'}"
        puts "  Remaining properties: #{status[:remaining_properties] || 'Unlimited'}"

        if status[:features].any?
          puts "\nFeatures: #{status[:features].join(', ')}"
        end

        puts "\nEvents:"
        subscription.events.order(created_at: :desc).limit(5).each do |event|
          puts "  #{event.created_at.strftime('%Y-%m-%d %H:%M')} - #{event.event_type}"
        end
      end

      puts "=" * 60
    end

    desc "Create a trial subscription for a website"
    task :create, [:subdomain, :plan_slug, :trial_days] => :environment do |_t, args|
      subdomain = args[:subdomain]
      plan_slug = args[:plan_slug]
      trial_days = args[:trial_days]&.to_i

      if subdomain.blank?
        puts "Usage: rails pwb:subscriptions:create[subdomain,plan-slug,trial-days]"
        puts "  subdomain: Required - the website subdomain"
        puts "  plan-slug: Optional - defaults to starter plan"
        puts "  trial-days: Optional - defaults to plan's trial period"
        puts "\nExample: rails pwb:subscriptions:create[mysite,professional,30]"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)

      if website.nil?
        puts "Error: Website '#{subdomain}' not found"
        exit 1
      end

      plan = if plan_slug.present?
               Pwb::Plan.find_by(slug: plan_slug)
             else
               Pwb::Plan.default_plan
             end

      if plan.nil?
        puts "Error: Plan '#{plan_slug}' not found"
        puts "Run 'rails pwb:plans:list' to see available plans"
        exit 1
      end

      if website.subscription&.allows_access?
        puts "Error: Website already has an active subscription"
        puts "Current plan: #{website.subscription.plan.display_name}"
        puts "Status: #{website.subscription.status}"
        exit 1
      end

      puts "\nCreating subscription:"
      puts "  Website: #{subdomain}"
      puts "  Plan: #{plan.display_name}"
      puts "  Trial days: #{trial_days || plan.trial_days}"

      service = Pwb::SubscriptionService.new
      result = service.create_trial(website: website, plan: plan, trial_days: trial_days)

      if result[:success]
        puts "\nSubscription created successfully!"
        puts "  Status: #{result[:subscription].status}"
        puts "  Trial ends: #{result[:subscription].trial_ends_at.strftime('%Y-%m-%d %H:%M')}"
      else
        puts "\nError creating subscription:"
        result[:errors].each { |e| puts "  - #{e}" }
        exit 1
      end
    end

    desc "Activate a subscription (convert from trial to active)"
    task :activate, [:subdomain] => :environment do |_t, args|
      subdomain = args[:subdomain]

      if subdomain.blank?
        puts "Usage: rails pwb:subscriptions:activate[subdomain]"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)

      if website.nil?
        puts "Error: Website '#{subdomain}' not found"
        exit 1
      end

      subscription = website.subscription

      if subscription.nil?
        puts "Error: No subscription found for '#{subdomain}'"
        exit 1
      end

      if subscription.active?
        puts "Subscription is already active."
        exit 0
      end

      puts "\nActivating subscription:"
      puts "  Website: #{subdomain}"
      puts "  Plan: #{subscription.plan.display_name}"
      puts "  Current status: #{subscription.status}"

      service = Pwb::SubscriptionService.new
      result = service.activate(subscription: subscription)

      if result[:success]
        puts "\nSubscription activated successfully!"
        puts "  New status: #{result[:subscription].status}"
      else
        puts "\nError activating subscription:"
        result[:errors].each { |e| puts "  - #{e}" }
        exit 1
      end
    end

    desc "Cancel a subscription"
    task :cancel, [:subdomain, :immediate] => :environment do |_t, args|
      subdomain = args[:subdomain]
      immediate = args[:immediate]&.downcase == 'true'

      if subdomain.blank?
        puts "Usage: rails pwb:subscriptions:cancel[subdomain,immediate]"
        puts "  subdomain: Required - the website subdomain"
        puts "  immediate: Optional - 'true' to cancel immediately, otherwise cancels at period end"
        puts "\nExample: rails pwb:subscriptions:cancel[mysite]"
        puts "Example: rails pwb:subscriptions:cancel[mysite,true]"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)

      if website.nil?
        puts "Error: Website '#{subdomain}' not found"
        exit 1
      end

      subscription = website.subscription

      if subscription.nil?
        puts "Error: No subscription found for '#{subdomain}'"
        exit 1
      end

      if subscription.canceled?
        puts "Subscription is already canceled."
        exit 0
      end

      puts "\nCanceling subscription:"
      puts "  Website: #{subdomain}"
      puts "  Plan: #{subscription.plan.display_name}"
      puts "  Current status: #{subscription.status}"
      puts "  Cancel immediately: #{immediate}"
      puts "  Period ends: #{subscription.current_period_ends_at&.strftime('%Y-%m-%d')}"

      print "\nAre you sure? (y/n): "
      unless $stdin.gets.chomp.downcase == 'y'
        puts "Cancellation aborted."
        exit 0
      end

      service = Pwb::SubscriptionService.new
      result = service.cancel(subscription: subscription, at_period_end: !immediate, reason: 'Canceled via rake task')

      if result[:success]
        if immediate
          puts "\nSubscription canceled immediately."
        else
          puts "\nSubscription will be canceled at period end (#{subscription.current_period_ends_at&.strftime('%Y-%m-%d')})."
        end
      else
        puts "\nError canceling subscription:"
        result[:errors].each { |e| puts "  - #{e}" }
        exit 1
      end
    end

    desc "Change a subscription's plan"
    task :change_plan, [:subdomain, :new_plan_slug] => :environment do |_t, args|
      subdomain = args[:subdomain]
      new_plan_slug = args[:new_plan_slug]

      if subdomain.blank? || new_plan_slug.blank?
        puts "Usage: rails pwb:subscriptions:change_plan[subdomain,new-plan-slug]"
        puts "\nExample: rails pwb:subscriptions:change_plan[mysite,professional]"
        puts "\nRun 'rails pwb:plans:list' to see available plans"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)

      if website.nil?
        puts "Error: Website '#{subdomain}' not found"
        exit 1
      end

      subscription = website.subscription

      if subscription.nil?
        puts "Error: No subscription found for '#{subdomain}'"
        puts "Create one first with: rails pwb:subscriptions:create[#{subdomain},#{new_plan_slug}]"
        exit 1
      end

      new_plan = Pwb::Plan.find_by(slug: new_plan_slug)

      if new_plan.nil?
        puts "Error: Plan '#{new_plan_slug}' not found"
        puts "Run 'rails pwb:plans:list' to see available plans"
        exit 1
      end

      if subscription.plan == new_plan
        puts "Subscription is already on the '#{new_plan.display_name}' plan."
        exit 0
      end

      puts "\nChanging subscription plan:"
      puts "  Website: #{subdomain}"
      puts "  Current plan: #{subscription.plan.display_name} (#{subscription.plan.formatted_price})"
      puts "  New plan: #{new_plan.display_name} (#{new_plan.formatted_price})"

      # Check for potential issues
      if new_plan.property_limit.present?
        current_properties = website.props.count
        if current_properties > new_plan.property_limit
          puts "\n*** WARNING ***"
          puts "Website has #{current_properties} properties but new plan only allows #{new_plan.property_limit}."
          puts "Plan change will be rejected."
        end
      end

      print "\nProceed with plan change? (y/n): "
      unless $stdin.gets.chomp.downcase == 'y'
        puts "Plan change aborted."
        exit 0
      end

      service = Pwb::SubscriptionService.new
      result = service.change_plan(subscription: subscription, new_plan: new_plan)

      if result[:success]
        puts "\nPlan changed successfully!"
        puts "  Old plan: #{result[:old_plan].display_name}"
        puts "  New plan: #{result[:new_plan].display_name}"
      else
        puts "\nError changing plan:"
        result[:errors].each { |e| puts "  - #{e}" }
        exit 1
      end
    end

    desc "Reactivate an expired or canceled subscription"
    task :reactivate, [:subdomain, :plan_slug] => :environment do |_t, args|
      subdomain = args[:subdomain]
      plan_slug = args[:plan_slug]

      if subdomain.blank?
        puts "Usage: rails pwb:subscriptions:reactivate[subdomain,plan-slug]"
        puts "  subdomain: Required - the website subdomain"
        puts "  plan-slug: Optional - use a different plan (defaults to previous plan)"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)

      if website.nil?
        puts "Error: Website '#{subdomain}' not found"
        exit 1
      end

      old_subscription = website.subscription

      if old_subscription&.allows_access?
        puts "Error: Website already has an active subscription"
        puts "Status: #{old_subscription.status}"
        exit 1
      end

      plan = if plan_slug.present?
               Pwb::Plan.find_by(slug: plan_slug)
             elsif old_subscription&.plan
               old_subscription.plan
             else
               Pwb::Plan.default_plan
             end

      if plan.nil?
        puts "Error: Plan not found"
        exit 1
      end

      puts "\nReactivating subscription:"
      puts "  Website: #{subdomain}"
      puts "  Plan: #{plan.display_name}"
      if old_subscription
        puts "  Previous status: #{old_subscription.status}"
      end

      # Remove the old subscription if it exists and is expired/canceled
      if old_subscription && (old_subscription.expired? || old_subscription.canceled?)
        old_subscription.destroy
      end

      service = Pwb::SubscriptionService.new
      result = service.create_trial(website: website, plan: plan)

      if result[:success]
        puts "\nSubscription reactivated successfully!"
        puts "  Status: #{result[:subscription].status}"
        puts "  Trial ends: #{result[:subscription].trial_ends_at.strftime('%Y-%m-%d %H:%M')}"
      else
        puts "\nError reactivating subscription:"
        result[:errors].each { |e| puts "  - #{e}" }
        exit 1
      end
    end
  end
end
