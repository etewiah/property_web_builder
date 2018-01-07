class CreatePwbPageContents < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_page_contents do |t|
      # when true, is_rails_part indicates to
      # use rails template instead of content from db
      # also in page part model
      t.boolean :is_rails_part, default: false
      # considering replacing with is_vue_component 
      # t.boolean :is_vue_component, default: false
      t.string :page_part_key
      t.string :label
      t.integer :sort_order
      # t.string :fragment_key, index: true
      t.boolean :visible_on_page, default: true
      # t.integer :page_id
      # t.integer :content_id
      t.belongs_to :page, index: true
      t.belongs_to :content, index: true
      t.timestamps
    end
  end
end
