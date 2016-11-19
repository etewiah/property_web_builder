# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161118222543) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "pwb_agencies", force: :cascade do |t|
    t.string   "phone_number_primary"
    t.string   "phone_number_mobile"
    t.string   "phone_number_other"
    t.string   "analytics_id"
    t.integer  "analytics_id_type"
    t.string   "company_name"
    t.string   "display_name"
    t.string   "email"
    t.string   "skype"
    t.string   "company_id"
    t.integer  "company_id_type"
    t.string   "url"
    t.integer  "primary_address_id"
    t.integer  "secondary_address_id"
    t.integer  "flags",                default: 0,    null: false
    t.integer  "payment_plan_id"
    t.json     "social_media",         default: "{}"
    t.json     "details",              default: "{}"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.index ["company_id"], name: "index_pwb_agencies_on_company_id", unique: true, using: :btree
    t.index ["company_name"], name: "index_pwb_agencies_on_company_name", using: :btree
  end

  create_table "pwb_content_photos", force: :cascade do |t|
    t.integer  "content_id"
    t.string   "image"
    t.string   "description"
    t.integer  "sort_order"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "pwb_content_translations", force: :cascade do |t|
    t.integer  "pwb_content_id", null: false
    t.string   "locale",         null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.text     "raw"
    t.index ["locale"], name: "index_pwb_content_translations_on_locale", using: :btree
    t.index ["pwb_content_id"], name: "index_pwb_content_translations_on_pwb_content_id", using: :btree
  end

  create_table "pwb_contents", force: :cascade do |t|
    t.string   "key"
    t.string   "tag"
    t.string   "input_type"
    t.string   "status"
    t.integer  "last_updated_by_user_id"
    t.integer  "sort_order"
    t.string   "target_url"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.index ["key"], name: "index_pwb_contents_on_key", unique: true, using: :btree
  end

end
