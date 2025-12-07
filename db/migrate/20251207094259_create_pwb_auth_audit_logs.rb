class CreatePwbAuthAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_auth_audit_logs do |t|
      # User reference (nullable for failed logins with unknown email)
      t.references :user, foreign_key: { to_table: :pwb_users }, null: true

      # Website/tenant context
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: true

      # Event details
      t.string :event_type, null: false  # login_success, login_failure, logout, etc.
      t.string :email                     # Email attempted (for failed logins)
      t.string :provider                  # OAuth provider if applicable

      # Request context
      t.string :ip_address
      t.string :user_agent
      t.string :request_path

      # Additional metadata (JSON)
      t.jsonb :metadata, default: {}

      # Failure tracking
      t.string :failure_reason            # Invalid password, locked, etc.

      t.timestamps
    end

    # Indexes for common queries
    add_index :pwb_auth_audit_logs, :event_type
    add_index :pwb_auth_audit_logs, :email
    add_index :pwb_auth_audit_logs, :ip_address
    add_index :pwb_auth_audit_logs, :created_at
    add_index :pwb_auth_audit_logs, [:user_id, :event_type]
    add_index :pwb_auth_audit_logs, [:website_id, :event_type]
  end
end
