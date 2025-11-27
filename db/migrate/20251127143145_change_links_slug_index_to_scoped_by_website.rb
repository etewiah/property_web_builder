class ChangeLinksSlugIndexToScopedByWebsite < ActiveRecord::Migration[8.0]
  def change
    # Remove the old global unique index on slug
    remove_index :pwb_links, name: :index_pwb_links_on_slug

    # Add a new unique index scoped to website_id
    add_index :pwb_links, [:website_id, :slug], unique: true, name: :index_pwb_links_on_website_id_and_slug
  end
end
