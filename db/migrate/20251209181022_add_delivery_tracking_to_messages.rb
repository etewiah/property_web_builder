class AddDeliveryTrackingToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_messages, :delivered_at, :datetime
    add_column :pwb_messages, :delivery_error, :text
  end
end
