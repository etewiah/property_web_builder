# frozen_string_literal: true

namespace :subscriptions do
  # Configuration file paths (checked in order of preference)
  CONFIG_PATHS = [
    'config/subscription_plans.yml',
    'config/subscription_plans.yaml',
    'config/subscription_plans.json'
  ].freeze

  desc "Seed subscription plans from config file"
  task seed_plans: :environment do
    config_file = find_config_file
    abort "ERROR: No config file found. Expected one of:\n  #{CONFIG_PATHS.join("\n  ")}" unless config_file

    puts "Loading plans from: #{config_file}"
    plans = load_plans_from_file(config_file)

    if plans.empty?
      abort "ERROR: No plans found in config file"
    end

    puts "Seeding #{plans.count} subscription plans..."
    puts ""

    plans.each do |plan_attrs|
      plan_attrs = plan_attrs.deep_symbolize_keys
      slug = plan_attrs[:slug]

      plan = Pwb::Plan.find_or_initialize_by(slug: slug)
      plan.assign_attributes(plan_attrs)

      if plan.save
        status = plan.previously_new_record? ? 'Created' : 'Updated'
        puts "  #{status}: #{plan.display_name} (#{plan.formatted_price})"
        puts "    - Trial: #{plan.formatted_trial_period}"
        puts "    - Property limit: #{plan.property_limit || 'Unlimited'}"
        puts "    - Features: #{plan.features.join(', ')}"
      else
        puts "  ERROR: #{plan.display_name} - #{plan.errors.full_messages.join(', ')}"
      end
    end

    puts ""
    puts "Done! #{Pwb::Plan.count} plans in database."
  end

  desc "List all subscription plans"
  task list_plans: :environment do
    puts ""
    puts "=" * 70
    puts "Subscription Plans"
    puts "=" * 70

    Pwb::Plan.ordered.each do |plan|
      puts ""
      puts "#{plan.display_name} (#{plan.slug})"
      puts "-" * 40
      puts "  Price: #{plan.formatted_price}"
      puts "  Properties: #{plan.property_limit || 'Unlimited'}"
      puts "  Users: #{plan.user_limit || 'Unlimited'}"
      puts "  Trial: #{plan.formatted_trial_period}"
      puts "  Status: #{plan.active? ? 'Active' : 'Inactive'} | #{plan.public? ? 'Public' : 'Hidden'}"
      puts "  Features:"
      plan.features.each do |feature|
        desc = Pwb::Plan::FEATURES[feature.to_sym] || feature.humanize
        puts "    - #{desc}"
      end
    end

    puts ""
    puts "=" * 70
    puts "Total: #{Pwb::Plan.count} plans (#{Pwb::Plan.active.count} active)"
    puts "=" * 70
  end

  desc "Validate config file without applying changes"
  task validate_config: :environment do
    config_file = find_config_file
    abort "ERROR: No config file found" unless config_file

    puts "Validating: #{config_file}"
    plans = load_plans_from_file(config_file)

    errors = []
    plans.each_with_index do |plan_attrs, index|
      plan_attrs = plan_attrs.deep_symbolize_keys
      plan = Pwb::Plan.new(plan_attrs)

      unless plan.valid?
        errors << "Plan #{index + 1} (#{plan_attrs[:slug] || 'unknown'}): #{plan.errors.full_messages.join(', ')}"
      end
    end

    if errors.any?
      puts ""
      puts "Validation FAILED:"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    else
      puts "Validation PASSED: #{plans.count} plans are valid"
    end
  end

  desc "Export current plans to YAML"
  task export_yaml: :environment do
    output = { 'plans' => [] }

    Pwb::Plan.ordered.each do |plan|
      plan_hash = {
        'name' => plan.name,
        'slug' => plan.slug,
        'display_name' => plan.display_name,
        'description' => plan.description,
        'price_cents' => plan.price_cents,
        'price_currency' => plan.price_currency,
        'billing_interval' => plan.billing_interval,
        'property_limit' => plan.property_limit,
        'user_limit' => plan.user_limit,
        'position' => plan.position,
        'active' => plan.active,
        'public' => plan.public,
        'features' => plan.features
      }
      # Include trial span
      plan_hash['trial_value'] = plan.trial_value if plan.trial_value.present?
      plan_hash['trial_unit'] = plan.trial_unit if plan.trial_unit.present?
      output['plans'] << plan_hash
    end

    puts output.to_yaml
  end

  desc "Export current plans to JSON"
  task export_json: :environment do
    output = { plans: [] }

    Pwb::Plan.ordered.each do |plan|
      plan_hash = {
        name: plan.name,
        slug: plan.slug,
        display_name: plan.display_name,
        description: plan.description,
        price_cents: plan.price_cents,
        price_currency: plan.price_currency,
        billing_interval: plan.billing_interval,
        property_limit: plan.property_limit,
        user_limit: plan.user_limit,
        position: plan.position,
        active: plan.active,
        public: plan.public,
        features: plan.features
      }
      # Include trial span
      plan_hash[:trial_value] = plan.trial_value if plan.trial_value.present?
      plan_hash[:trial_unit] = plan.trial_unit if plan.trial_unit.present?
      output[:plans] << plan_hash
    end

    puts JSON.pretty_generate(output)
  end

  desc "Reset plans (destroy all and reseed)"
  task reset_plans: :environment do
    puts "WARNING: This will delete all existing plans!"
    puts ""

    if Pwb::Subscription.exists?
      puts "Cannot reset: #{Pwb::Subscription.count} active subscriptions exist."
      puts "Use `rake subscriptions:seed_plans` to update plans instead (preserves existing)."
      exit 1
    end

    puts "Deleting existing plans..."
    Pwb::Plan.destroy_all

    Rake::Task['subscriptions:seed_plans'].invoke
  end

  # Helper methods
  def find_config_file
    CONFIG_PATHS.map { |p| Rails.root.join(p) }.find(&:exist?)
  end

  def load_plans_from_file(path)
    content = File.read(path)

    case File.extname(path).downcase
    when '.yml', '.yaml'
      data = YAML.safe_load(content, permitted_classes: [Symbol])
    when '.json'
      data = JSON.parse(content)
    else
      abort "ERROR: Unsupported file format: #{File.extname(path)}"
    end

    data['plans'] || data[:plans] || []
  end
end
