# frozen_string_literal: true

class AddSelectedPaletteToWebsites < ActiveRecord::Migration[7.1]
  def change
    add_column :pwb_websites, :selected_palette, :string

    # Add an index for efficient lookups
    add_index :pwb_websites, :selected_palette
  end
end
