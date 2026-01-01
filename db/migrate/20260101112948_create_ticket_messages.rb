class CreateTicketMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_ticket_messages, id: :uuid do |t|
      t.references :support_ticket, type: :uuid, foreign_key: { to_table: :pwb_support_tickets }, null: false
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false

      # Author
      t.references :user, foreign_key: { to_table: :pwb_users }, null: false
      t.boolean :from_platform_admin, default: false

      # Content
      t.text :content, null: false
      t.boolean :internal_note, default: false

      # Status change tracking (for audit trail)
      t.string :status_changed_from, limit: 50
      t.string :status_changed_to, limit: 50

      t.timestamps
    end

    add_index :pwb_ticket_messages, [:support_ticket_id, :created_at]
    add_index :pwb_ticket_messages, [:website_id, :created_at]
  end
end
