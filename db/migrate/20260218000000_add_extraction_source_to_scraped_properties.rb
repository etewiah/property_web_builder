# frozen_string_literal: true

class AddExtractionSourceToScrapedProperties < ActiveRecord::Migration[7.1]
  def change
    add_column :pwb_scraped_properties, :extraction_source, :string
  end
end
