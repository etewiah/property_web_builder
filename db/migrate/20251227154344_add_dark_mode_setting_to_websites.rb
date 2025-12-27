# frozen_string_literal: true

class AddDarkModeSettingToWebsites < ActiveRecord::Migration[8.1]
  def change
    # Dark mode settings: 'light_only', 'auto', 'dark'
    # - light_only: Only light mode colors, no dark mode CSS
    # - auto: Respects user's system preference (prefers-color-scheme)
    # - dark: Forces dark mode
    add_column :pwb_websites, :dark_mode_setting, :string, default: 'light_only', null: false
    add_index :pwb_websites, :dark_mode_setting
  end
end
