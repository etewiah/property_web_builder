class CreatePwbTestimonials < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_testimonials do |t|
      t.string :author_name, null: false
      t.string :author_role
      t.text :quote, null: false
      t.integer :rating
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false
      t.boolean :featured, default: false, null: false

      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :author_photo, foreign_key: { to_table: :pwb_media }

      t.timestamps
    end

    add_index :pwb_testimonials, :visible
    add_index :pwb_testimonials, :position
  end
end
