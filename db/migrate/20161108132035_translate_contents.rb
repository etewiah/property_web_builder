class TranslateContents < ActiveRecord::Migration[5.0]
  def self.up
    Pwb::Content.create_translation_table!({
                                             raw: :text
                                           }, migrate_data: true)
  end

  def self.down
    Pwb::Content.drop_translation_table! migrate_data: true
  end
end
