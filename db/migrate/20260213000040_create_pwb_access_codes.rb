# frozen_string_literal: true

class CreatePwbAccessCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_access_codes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.bigint   :website_id, null: false
      t.string   :code, null: false
      t.boolean  :active, default: true, null: false
      t.integer  :uses_count, default: 0, null: false
      t.integer  :max_uses
      t.datetime :expires_at

      t.timestamps
    end

    add_index :pwb_access_codes, [:website_id, :code], unique: true
    add_index :pwb_access_codes, :website_id

    add_foreign_key :pwb_access_codes, :pwb_websites, column: :website_id
  end
end
