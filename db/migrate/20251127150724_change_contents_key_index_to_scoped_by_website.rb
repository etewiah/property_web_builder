class ChangeContentsKeyIndexToScopedByWebsite < ActiveRecord::Migration[8.0]
  def change
    # Remove the old global unique index on key
    remove_index :pwb_contents, name: :index_pwb_contents_on_key

    # Add a new unique index scoped to website_id
    # This allows different websites to have content with the same key
    add_index :pwb_contents, [:website_id, :key], unique: true, name: :index_pwb_contents_on_website_id_and_key
  end
end
