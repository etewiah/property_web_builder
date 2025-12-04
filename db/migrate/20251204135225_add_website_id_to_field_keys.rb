class AddWebsiteIdToFieldKeys < ActiveRecord::Migration[8.0]
  def change
    # Add website_id column for tenant scoping
    add_reference :pwb_field_keys, :pwb_website,
                  foreign_key: { to_table: :pwb_websites },
                  index: true,
                  null: true # Allow null initially for existing records
    
    # Add composite index for efficient tenant-scoped queries
    add_index :pwb_field_keys, [:pwb_website_id, :tag], name: 'index_field_keys_on_website_and_tag'
  end
end
