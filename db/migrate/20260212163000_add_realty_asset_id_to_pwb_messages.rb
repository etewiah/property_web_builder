# frozen_string_literal: true

class AddRealtyAssetIdToPwbMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_messages, :realty_asset_id, :uuid
    add_index :pwb_messages, :realty_asset_id
  end
end
