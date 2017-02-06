class AddAreaUnitToProp < ActiveRecord::Migration[5.0]
# https://www.sitepoint.com/enumerated-types-with-activerecord-and-postgresql/
  def change
    add_column :pwb_props, :area_unit, :integer, default: 0, index: true
  end
end
