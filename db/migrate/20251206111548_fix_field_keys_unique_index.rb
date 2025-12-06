# frozen_string_literal: true

class FixFieldKeysUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    # Remove old unique index on global_key alone.
    # This was preventing the same field key name from existing across different websites.
    if index_exists?(:pwb_field_keys, :global_key, name: 'index_pwb_field_keys_on_global_key')
      remove_index :pwb_field_keys, name: 'index_pwb_field_keys_on_global_key'
    end

    # Add composite unique index scoped by website.
    # This allows the same global_key to exist in different websites,
    # while preventing duplicates within the same website.
    unless index_exists?(:pwb_field_keys, [:pwb_website_id, :global_key])
      add_index :pwb_field_keys,
                [:pwb_website_id, :global_key],
                unique: true,
                name: 'index_field_keys_unique_per_website'
    end
  end

  def down
    # Restore original unique index on global_key alone
    if index_exists?(:pwb_field_keys, [:pwb_website_id, :global_key], name: 'index_field_keys_unique_per_website')
      remove_index :pwb_field_keys, name: 'index_field_keys_unique_per_website'
    end

    unless index_exists?(:pwb_field_keys, :global_key)
      add_index :pwb_field_keys, :global_key, unique: true
    end
  end
end
