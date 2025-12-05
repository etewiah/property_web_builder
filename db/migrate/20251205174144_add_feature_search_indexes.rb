class AddFeatureSearchIndexes < ActiveRecord::Migration[8.0]
  def change
    # Index on feature_key for fast lookups when filtering by feature
    unless index_exists?(:pwb_features, :feature_key)
      add_index :pwb_features, :feature_key
    end

    # Composite index for realty_asset + feature queries (JOIN optimization)
    unless index_exists?(:pwb_features, [:realty_asset_id, :feature_key])
      add_index :pwb_features, [:realty_asset_id, :feature_key]
    end

    # Index on prop_state_key for state filtering
    unless index_exists?(:pwb_realty_assets, :prop_state_key)
      add_index :pwb_realty_assets, :prop_state_key
    end

    # Index on prop_type_key for type filtering
    unless index_exists?(:pwb_realty_assets, :prop_type_key)
      add_index :pwb_realty_assets, :prop_type_key
    end

    # Composite index for common multi-tenant search patterns
    unless index_exists?(:pwb_realty_assets, [:website_id, :prop_type_key])
      add_index :pwb_realty_assets, [:website_id, :prop_type_key]
    end
  end
end
