# Prevents duplicate reserved subdomains per email address.
# This is a safety net - the application code in Subdomain.reserve_for_email
# should already prevent this, but this ensures data integrity at the DB level.
#
# The partial index only applies when:
# - aasm_state = 'reserved' (not available, allocated, or released)
# - reserved_by_email is not null
#
class AddUniqueReservedEmailIndexToSubdomains < ActiveRecord::Migration[8.1]
  def change
    # Add partial unique index: only one reserved subdomain per email
    add_index :pwb_subdomains,
              :reserved_by_email,
              unique: true,
              where: "aasm_state = 'reserved' AND reserved_by_email IS NOT NULL",
              name: 'index_subdomains_unique_reserved_email'
  end
end
