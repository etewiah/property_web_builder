class AddContactIdToPwbMessages < ActiveRecord::Migration[5.1]
  def change
    add_column :pwb_messages, :contact_id, :integer, index: true
  end
end
