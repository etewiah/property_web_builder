class AddThemeNameToPwbAgency < ActiveRecord::Migration[5.0]
  def change
    add_column :pwb_agencies, :theme_name, :string
  end
end
