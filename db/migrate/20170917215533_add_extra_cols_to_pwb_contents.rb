class AddExtraColsToPwbContents < ActiveRecord::Migration[5.1]
  def change
    add_column :pwb_contents, :fragment_key, :string, index: true
    # add_column :pwb_contents, :visible_on_page, :boolean, default: true
    # , index: true
  end
end
