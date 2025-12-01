class CreatePwbUserMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_user_memberships do |t|
      t.references :user, null: false, foreign_key: { to_table: :pwb_users }
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :role, null: false, default: 'member'
      t.boolean :active, default: true, null: false

      t.timestamps
      
      # Ensure user can only have one membership per website
      t.index [:user_id, :website_id], unique: true, name: 'index_user_memberships_on_user_and_website'
    end
  end
end
