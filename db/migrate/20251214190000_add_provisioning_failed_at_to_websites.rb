# Add provisioning_failed_at timestamp and update existing data to use new states
class AddProvisioningFailedAtToWebsites < ActiveRecord::Migration[8.1]
  def up
    # Add the new column
    add_column :pwb_websites, :provisioning_failed_at, :datetime

    # Migrate existing data to new states
    # Old states: pending, subdomain_allocated, configuring, seeding, ready, live, failed, suspended, terminated
    # New states: pending, owner_assigned, agency_created, links_created, field_keys_created, properties_seeded, ready, live, failed, suspended, terminated

    # Map old intermediate states to best new equivalent
    execute <<-SQL
      UPDATE pwb_websites
      SET provisioning_state = 'owner_assigned'
      WHERE provisioning_state = 'subdomain_allocated';
    SQL

    execute <<-SQL
      UPDATE pwb_websites
      SET provisioning_state = 'agency_created'
      WHERE provisioning_state = 'configuring';
    SQL

    execute <<-SQL
      UPDATE pwb_websites
      SET provisioning_state = 'properties_seeded'
      WHERE provisioning_state = 'seeding';
    SQL

    # pending, ready, live, failed, suspended, terminated stay the same
  end

  def down
    remove_column :pwb_websites, :provisioning_failed_at

    # Reverse the state mappings
    execute <<-SQL
      UPDATE pwb_websites
      SET provisioning_state = 'subdomain_allocated'
      WHERE provisioning_state = 'owner_assigned';
    SQL

    execute <<-SQL
      UPDATE pwb_websites
      SET provisioning_state = 'configuring'
      WHERE provisioning_state IN ('agency_created', 'links_created', 'field_keys_created');
    SQL

    execute <<-SQL
      UPDATE pwb_websites
      SET provisioning_state = 'seeding'
      WHERE provisioning_state = 'properties_seeded';
    SQL
  end
end
