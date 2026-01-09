class AddMetadataToPwbUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_users, :metadata, :jsonb, default: {}, null: false

    # Add index for querying by Zoho lead ID
    add_index :pwb_users, "(metadata->>'zoho_lead_id')",
              name: 'index_pwb_users_on_zoho_lead_id',
              using: :btree,
              where: "metadata->>'zoho_lead_id' IS NOT NULL"
  end
end
