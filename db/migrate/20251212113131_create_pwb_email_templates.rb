# frozen_string_literal: true

class CreatePwbEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_email_templates do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :template_key, null: false
      t.string :name, null: false
      t.text :description
      t.string :subject, null: false
      t.text :body_html, null: false
      t.text :body_text
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    # Each website can only have one template per key
    add_index :pwb_email_templates, [:website_id, :template_key], unique: true
    add_index :pwb_email_templates, :template_key
    add_index :pwb_email_templates, :active
  end
end
