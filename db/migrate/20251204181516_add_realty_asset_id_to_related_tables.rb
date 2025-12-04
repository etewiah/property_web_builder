class AddRealtyAssetIdToRelatedTables < ActiveRecord::Migration[8.0]
  def change
    add_reference :pwb_prop_photos, :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
    add_reference :pwb_features, :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
    add_reference :pwb_prop_translations, :realty_asset, type: :uuid, foreign_key: { to_table: :pwb_realty_assets }
  end
end
