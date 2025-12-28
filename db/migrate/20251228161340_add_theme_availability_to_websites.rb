# frozen_string_literal: true

class AddThemeAvailabilityToWebsites < ActiveRecord::Migration[8.1]
  def change
    # Store available themes as a text array (like supported_locales)
    # NULL means use tenant defaults, empty array means no themes, array with values means specific themes
    add_column :pwb_websites, :available_themes, :text, array: true, default: nil
  end
end
