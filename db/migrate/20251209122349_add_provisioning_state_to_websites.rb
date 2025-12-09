class AddProvisioningStateToWebsites < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_websites, :provisioning_state, :string, null: false, default: 'live'
    add_column :pwb_websites, :site_type, :string  # residential, commercial, vacation_rental
    add_column :pwb_websites, :provisioning_started_at, :datetime
    add_column :pwb_websites, :provisioning_completed_at, :datetime
    add_column :pwb_websites, :provisioning_error, :text
    add_column :pwb_websites, :seed_pack_name, :string  # Track which seed pack was used

    add_index :pwb_websites, :provisioning_state
    add_index :pwb_websites, :site_type
  end
end
