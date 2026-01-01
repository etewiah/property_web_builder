class CreateSupportTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_support_tickets, id: :uuid do |t|
      # Tenant scoping
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false

      # Identification
      t.string :ticket_number, null: false, limit: 20

      # Content
      t.string :subject, null: false, limit: 255
      t.text :description

      # Classification
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 1, null: false
      t.string :category, limit: 50

      # Relationships
      t.references :creator, foreign_key: { to_table: :pwb_users }, null: false
      t.references :assigned_to, foreign_key: { to_table: :pwb_users }

      # Tracking
      t.datetime :assigned_at
      t.datetime :first_response_at
      t.datetime :resolved_at
      t.datetime :closed_at
      t.integer :message_count, default: 0
      t.datetime :last_message_at
      t.boolean :last_message_from_platform, default: false

      t.timestamps
    end

    add_index :pwb_support_tickets, :ticket_number, unique: true
    add_index :pwb_support_tickets, [:website_id, :status]
    add_index :pwb_support_tickets, [:website_id, :created_at]
    add_index :pwb_support_tickets, [:assigned_to_id, :status]
    add_index :pwb_support_tickets, :status
    add_index :pwb_support_tickets, :priority
  end
end
