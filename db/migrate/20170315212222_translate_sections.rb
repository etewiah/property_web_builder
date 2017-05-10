class TranslateSections < ActiveRecord::Migration[5.0]
# translated cols are not needed in original table
  def self.up
    Pwb::Section.create_translation_table!({
      :page_title => {:type => :string, :default => ''},
      :link_title => {:type => :string, :default => ''}
    }, {
      :migrate_data => true
    })
  end

  def self.down
    Pwb::Section.drop_translation_table! :migrate_data => true
  end
end
