class ChangeCountBathroomsForProp < ActiveRecord::Migration[5.0]
  def change
    # below needed to support 1.5 bathrooms in US
    change_column :pwb_props, :count_bathrooms, :float
  end
end

