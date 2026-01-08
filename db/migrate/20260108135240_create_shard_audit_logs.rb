class CreateShardAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_shard_audit_logs do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }, index: true
      t.string :old_shard_name
      t.string :new_shard_name, null: false
      t.string :changed_by_email, null: false
      t.string :notes
      t.string :status, default: 'completed', null: false
      
      t.timestamps
    end

    add_index :pwb_shard_audit_logs, :changed_by_email
    add_index :pwb_shard_audit_logs, :created_at
    add_index :pwb_shard_audit_logs, :status
  end
end
