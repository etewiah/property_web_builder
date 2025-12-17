class AddTranslationsToPwbFieldKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_field_keys, :translations, :jsonb, default: {}, null: false
  end
end
