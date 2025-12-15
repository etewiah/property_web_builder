# frozen_string_literal: true

class CreateSubscriptionSystem < ActiveRecord::Migration[8.0]
  def change
    # Plans table - defines available subscription tiers
    create_table :pwb_plans do |t|
      t.string :name, null: false          # Internal name (e.g., "starter")
      t.string :slug, null: false          # URL-friendly identifier
      t.string :display_name, null: false  # User-facing name (e.g., "Starter Plan")
      t.text :description                  # Marketing description

      # Pricing
      t.integer :price_cents, null: false, default: 0
      t.string :price_currency, null: false, default: 'USD'
      t.string :billing_interval, null: false, default: 'month' # month, year

      # Trial
      t.integer :trial_days, null: false, default: 14

      # Limits
      t.integer :property_limit           # null = unlimited
      t.integer :user_limit               # null = unlimited

      # Features (jsonb array of feature keys)
      t.jsonb :features, null: false, default: []

      # Metadata
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0  # For ordering in UI
      t.boolean :public, null: false, default: true # Show on pricing page

      t.timestamps
    end

    add_index :pwb_plans, :slug, unique: true
    add_index :pwb_plans, [:active, :position]

    # Subscriptions table - links websites to plans
    create_table :pwb_subscriptions do |t|
      # Use index: false to avoid auto-generated index, we'll add unique one manually
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }, index: false
      t.references :plan, null: false, foreign_key: { to_table: :pwb_plans }

      # Status (managed by AASM)
      t.string :status, null: false, default: 'trialing'

      # Trial period
      t.datetime :trial_ends_at

      # Billing period
      t.datetime :current_period_starts_at
      t.datetime :current_period_ends_at

      # Cancellation
      t.datetime :canceled_at
      t.boolean :cancel_at_period_end, null: false, default: false

      # External payment provider integration (future)
      t.string :external_provider        # 'stripe', 'paddle', etc.
      t.string :external_id              # Provider's subscription ID
      t.string :external_customer_id     # Provider's customer ID

      # Metadata
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :pwb_subscriptions, :website_id, unique: true, name: 'index_pwb_subscriptions_on_website_unique'
    add_index :pwb_subscriptions, :status
    add_index :pwb_subscriptions, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :pwb_subscriptions, :trial_ends_at
    add_index :pwb_subscriptions, :current_period_ends_at

    # Subscription events table - audit log for subscription changes
    create_table :pwb_subscription_events do |t|
      t.references :subscription, null: false, foreign_key: { to_table: :pwb_subscriptions }

      t.string :event_type, null: false  # created, activated, canceled, expired, plan_changed, etc.
      t.jsonb :metadata, null: false, default: {}  # Event-specific data (old_plan, new_plan, etc.)

      t.datetime :created_at, null: false
    end

    add_index :pwb_subscription_events, [:subscription_id, :created_at]
    add_index :pwb_subscription_events, :event_type
  end
end
