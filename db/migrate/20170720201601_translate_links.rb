class TranslateLinks < ActiveRecord::Migration[5.0]
  def self.up
    Pwb::Link.create_translation_table!({
      :link_title => {:type => :string, :default => ''}
    }, {
      :migrate_data => true
    })
  end

  def self.down
    Pwb::Link.drop_translation_table! :migrate_data => true
  end
end
