class AddShardNameToPwbWebsites < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_websites, :shard_name, :string, default: "default"
  end
end
