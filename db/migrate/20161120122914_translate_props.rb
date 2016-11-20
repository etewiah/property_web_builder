class TranslateProps < ActiveRecord::Migration[5.0]
  def self.up
    Pwb::Prop.create_translation_table!({
      :title => {:type => :string, :default => ''},
      :description => {:type => :text, :default => ''}
      # null false below was creating errors when a new prop was created with no title
      # :title => {:type => :string, :null => false, :default => ''},
      # :description => {:type => :text, :null => false, :default => ''}
    }, {
      :migrate_data => true
    })
  end

  def self.down
    Pwb::Prop.drop_translation_table! :migrate_data => true
  end
end