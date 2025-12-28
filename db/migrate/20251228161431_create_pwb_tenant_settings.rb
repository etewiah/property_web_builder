# frozen_string_literal: true

class CreatePwbTenantSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_tenant_settings do |t|
      # Singleton key - ensures only one record exists
      t.string :singleton_key, null: false, default: 'default'

      # Theme settings
      t.text :default_available_themes, array: true, default: []

      # Future settings can be added here
      t.jsonb :configuration, default: {}

      t.timestamps
    end

    add_index :pwb_tenant_settings, :singleton_key, unique: true
  end
end
