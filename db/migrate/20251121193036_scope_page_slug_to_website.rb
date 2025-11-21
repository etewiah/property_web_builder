class ScopePageSlugToWebsite < ActiveRecord::Migration[8.0]
  def change
    remove_index :pwb_pages, :slug
    add_index :pwb_pages, [:slug, :website_id], unique: true
  end
end
