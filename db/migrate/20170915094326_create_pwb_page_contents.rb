class CreatePwbPageContents < ActiveRecord::Migration[5.1]
  def change
    create_table :pwb_page_contents do |t|
      t.string :label
      t.integer :sort_order
      # t.integer :page_id
      # t.integer :content_id
      t.belongs_to :page, index: true
      t.belongs_to :content, index: true
      t.timestamps
    end
  end
end
