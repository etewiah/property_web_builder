class AddAvailableCurrenciesToPwbWebsites < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_websites, :available_currencies, :text, array: true, default: []
  end
end
