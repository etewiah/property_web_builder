class AddFragmentKeyToPwbContents < ActiveRecord::Migration[5.1]
  def change
    add_column :pwb_contents, :page_part_key, :string, index: true
    # add_column :pwb_contents, :visible_on_page, :boolean, default: true
    # , index: true
  end
end
