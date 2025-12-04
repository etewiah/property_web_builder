class AddSortOrderToFieldKeys < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_field_keys, :sort_order, :integer, default: 0
  end
end
