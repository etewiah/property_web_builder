class UpdatePwbPropertiesToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_view :pwb_properties, version: 3, revert_to_version: 2, materialized: true
  end
end
