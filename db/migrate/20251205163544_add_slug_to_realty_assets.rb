class AddSlugToRealtyAssets < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_realty_assets, :slug, :string
    add_index :pwb_realty_assets, :slug, unique: true
  end
end
