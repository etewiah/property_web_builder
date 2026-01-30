# frozen_string_literal: true

class CreatePwbAiWritingRules < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_ai_writing_rules do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      t.string :name, null: false
      t.text :description
      t.text :rule_content, null: false  # The actual writing guideline
      t.boolean :active, default: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :pwb_ai_writing_rules, [:website_id, :active]
  end
end
