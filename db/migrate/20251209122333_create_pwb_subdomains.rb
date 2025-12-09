class CreatePwbSubdomains < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_subdomains do |t|
      t.string :name, null: false
      t.string :aasm_state, null: false, default: 'available'
      t.references :website, foreign_key: { to_table: :pwb_websites }
      t.datetime :reserved_at
      t.datetime :reserved_until
      t.string :reserved_by_email  # Track who reserved it before website exists

      t.timestamps

      t.index :name, unique: true
      t.index :aasm_state
      t.index [:aasm_state, :name]  # For finding available subdomains quickly
    end
  end
end
