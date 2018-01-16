class TranslatePages < ActiveRecord::Migration[5.0]
# translated cols are not needed in original table
# but need to have translations declared in model
  def self.up
    Pwb::Page.create_translation_table!({
      raw_html: {type: :text, default: ''},
      page_title: {type: :string, default: ''},
      link_title: {type: :string, default: ''}
    }, {
      migrate_data: true
    })
  end

  def self.down
    Pwb::Page.drop_translation_table! migrate_data: true
  end
end
