class AddReadToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_messages, :read, :boolean, default: false, null: false
  end
end
