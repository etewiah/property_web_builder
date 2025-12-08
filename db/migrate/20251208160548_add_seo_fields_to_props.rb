class AddSeoFieldsToProps < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_props, :seo_title, :string
    add_column :pwb_props, :meta_description, :text
  end
end
