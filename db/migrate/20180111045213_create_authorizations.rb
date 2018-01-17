class CreateAuthorizations < ActiveRecord::Migration[5.1]
  def change
    create_table :authorizations do |t|
      t.references :user, index: true
      t.string :provider
      t.string :uid
 
      t.timestamps
    end
  end
end
