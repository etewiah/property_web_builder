# frozen_string_literal: true

class AddUnreadMessagesCountToContacts < ActiveRecord::Migration[8.1]
  def up
    add_column :pwb_contacts, :unread_messages_count, :integer, default: 0, null: false

    # Backfill: count unread messages per contact scoped to same website
    execute <<~SQL
      UPDATE pwb_contacts
      SET unread_messages_count = (
        SELECT COUNT(*)
        FROM pwb_messages
        WHERE pwb_messages.contact_id = pwb_contacts.id
          AND pwb_messages.read = false
          AND pwb_messages.website_id = pwb_contacts.website_id
      )
    SQL
  end

  def down
    remove_column :pwb_contacts, :unread_messages_count
  end
end
