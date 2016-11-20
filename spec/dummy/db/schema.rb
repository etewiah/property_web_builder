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

ActiveRecord::Schema.define(version: 20161120122914) do

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
    t.string   "email_primary"
    t.string   "email_for_general_contact_form"
    t.string   "email_for_property_contact_form"
    t.string   "skype"
    t.string   "company_id"
    t.integer  "company_id_type"
    t.string   "url"
    t.integer  "primary_address_id"
    t.integer  "secondary_address_id"
    t.integer  "flags",                           default: 0,    null: false
    t.integer  "payment_plan_id"
    t.integer  "site_template_id"
    t.json     "site_configuration",              default: "{}"
    t.text     "supported_locales",               default: [],                array: true
    t.text     "supported_currencies",            default: [],                array: true
    t.string   "default_client_locale"
    t.string   "default_admin_locale"
    t.string   "default_currency"
    t.json     "social_media",                    default: "{}"
    t.json     "details",                         default: "{}"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
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

  create_table "pwb_prop_translations", force: :cascade do |t|
    t.integer  "pwb_prop_id",              null: false
    t.string   "locale",                   null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.string   "title",       default: ""
    t.text     "description", default: ""
    t.index ["locale"], name: "index_pwb_prop_translations_on_locale", using: :btree
    t.index ["pwb_prop_id"], name: "index_pwb_prop_translations_on_pwb_prop_id", using: :btree
  end

  create_table "pwb_props", force: :cascade do |t|
    t.string   "reference"
    t.integer  "year_construction",                             default: 0,     null: false
    t.integer  "count_bedrooms",                                default: 0,     null: false
    t.integer  "count_bathrooms",                               default: 0,     null: false
    t.integer  "count_toilets",                                 default: 0,     null: false
    t.integer  "count_garages",                                 default: 0,     null: false
    t.integer  "m_parcela",                                     default: 0,     null: false
    t.integer  "m_construidos",                                 default: 0,     null: false
    t.integer  "flags",                                         default: 0,     null: false
    t.boolean  "furnished"
    t.boolean  "sold"
    t.boolean  "reserved"
    t.boolean  "highlighted",                                   default: false
    t.boolean  "archived",                                      default: false
    t.boolean  "visible",                                       default: false
    t.boolean  "for_rent_short_term",                           default: false
    t.boolean  "for_rent_long_term",                            default: false
    t.boolean  "for_sale",                                      default: false
    t.boolean  "hide_map",                                      default: false
    t.boolean  "obscure_map",                                   default: false
    t.boolean  "portals_enabled",                               default: false
    t.datetime "deleted_at"
    t.datetime "active_from"
    t.datetime "available_to_rent_from"
    t.datetime "available_to_rent_till"
    t.integer  "price_sale_current_cents",                      default: 0,     null: false
    t.string   "price_sale_current_currency",                   default: "EUR", null: false
    t.integer  "price_sale_original_cents",                     default: 0,     null: false
    t.string   "price_sale_original_currency",                  default: "EUR", null: false
    t.integer  "price_rental_monthly_current_cents",            default: 0,     null: false
    t.string   "price_rental_monthly_current_currency",         default: "EUR", null: false
    t.integer  "price_rental_monthly_original_cents",           default: 0,     null: false
    t.string   "price_rental_monthly_original_currency",        default: "EUR", null: false
    t.integer  "price_rental_monthly_low_season_cents",         default: 0,     null: false
    t.string   "price_rental_monthly_low_season_currency",      default: "EUR", null: false
    t.integer  "price_rental_monthly_high_season_cents",        default: 0,     null: false
    t.string   "price_rental_monthly_high_season_currency",     default: "EUR", null: false
    t.integer  "price_rental_monthly_standard_season_cents",    default: 0,     null: false
    t.string   "price_rental_monthly_standard_season_currency", default: "EUR", null: false
    t.integer  "commission_cents",                              default: 0,     null: false
    t.string   "commission_currency",                           default: "EUR", null: false
    t.integer  "service_charge_yearly_cents",                   default: 0,     null: false
    t.string   "service_charge_yearly_currency",                default: "EUR", null: false
    t.string   "currency"
    t.string   "prop_origin_key",                               default: "",    null: false
    t.string   "prop_state_key",                                default: "",    null: false
    t.string   "prop_type_key",                                 default: "",    null: false
    t.string   "street_number"
    t.string   "street_name"
    t.string   "street_address"
    t.string   "postal_code"
    t.string   "province"
    t.string   "city"
    t.string   "region"
    t.string   "country"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.index ["archived"], name: "index_pwb_props_on_archived", using: :btree
    t.index ["flags"], name: "index_pwb_props_on_flags", using: :btree
    t.index ["for_rent_long_term"], name: "index_pwb_props_on_for_rent_long_term", using: :btree
    t.index ["for_rent_short_term"], name: "index_pwb_props_on_for_rent_short_term", using: :btree
    t.index ["for_sale"], name: "index_pwb_props_on_for_sale", using: :btree
    t.index ["highlighted"], name: "index_pwb_props_on_highlighted", using: :btree
    t.index ["latitude", "longitude"], name: "index_pwb_props_on_latitude_and_longitude", using: :btree
    t.index ["price_rental_monthly_current_cents"], name: "index_pwb_props_on_price_rental_monthly_current_cents", using: :btree
    t.index ["price_sale_current_cents"], name: "index_pwb_props_on_price_sale_current_cents", using: :btree
    t.index ["reference"], name: "index_pwb_props_on_reference", unique: true, using: :btree
    t.index ["visible"], name: "index_pwb_props_on_visible", using: :btree
  end

end
