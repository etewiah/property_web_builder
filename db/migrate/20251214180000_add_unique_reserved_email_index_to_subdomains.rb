# Prevents duplicate reserved subdomains per email address.
# This is a safety net - the application code in Subdomain.reserve_for_email
# should already prevent this, but this ensures data integrity at the DB level.
#
# The partial index only applies when:
# - aasm_state = 'reserved' (not available, allocated, or released)
# - reserved_by_email is not null
#
class AddUniqueReservedEmailIndexToSubdomains < ActiveRecord::Migration[8.1]
  def up
    # First, clean up any duplicate reservations that might exist
    # Keep the most recently updated reservation for each email, release others
    execute <<-SQL
      UPDATE pwb_subdomains
      SET aasm_state = 'available',
          reserved_by_email = NULL,
          reserved_at = NULL,
          reserved_until = NULL
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY reserved_by_email
                   ORDER BY updated_at DESC
                 ) as rn
          FROM pwb_subdomains
          WHERE aasm_state = 'reserved'
            AND reserved_by_email IS NOT NULL
        ) ranked
        WHERE rn > 1
      )
    SQL

    # Add partial unique index: only one reserved subdomain per email
    add_index :pwb_subdomains,
              :reserved_by_email,
              unique: true,
              where: "aasm_state = 'reserved' AND reserved_by_email IS NOT NULL",
              name: 'index_subdomains_unique_reserved_email'
  end

  def down
    remove_index :pwb_subdomains, name: 'index_subdomains_unique_reserved_email'
  end
end
