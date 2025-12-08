class AddSeoFieldsToPages < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_pages, :seo_title, :string
    add_column :pwb_pages, :meta_description, :text
  end
end
