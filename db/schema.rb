# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_08_160552) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "pwb_addresses", id: :serial, force: :cascade do |t|
    t.float "longitude"
    t.float "latitude"
    t.string "street_number"
    t.string "street_address"
    t.string "postal_code"
    t.string "city"
    t.string "region"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "pwb_agencies", id: :serial, force: :cascade do |t|
    t.string "phone_number_primary"
    t.string "phone_number_mobile"
    t.string "phone_number_other"
    t.string "analytics_id"
    t.integer "analytics_id_type"
    t.string "company_name"
    t.string "display_name"
    t.string "email_primary"
    t.string "email_for_general_contact_form"
    t.string "email_for_property_contact_form"
    t.string "skype"
    t.string "company_id"
    t.integer "company_id_type"
    t.string "url"
    t.integer "primary_address_id"
    t.integer "secondary_address_id"
    t.integer "flags", default: 0, null: false
    t.integer "payment_plan_id"
    t.integer "site_template_id"
    t.json "site_configuration", default: {}
    t.text "available_locales", default: [], array: true
    t.text "supported_locales", default: [], array: true
    t.text "available_currencies", default: [], array: true
    t.text "supported_currencies", default: [], array: true
    t.string "default_client_locale"
    t.string "default_admin_locale"
    t.string "default_currency"
    t.json "social_media", default: {}
    t.json "details", default: {}
    t.text "raw_css"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "theme_name"
    t.integer "website_id"
    t.index ["website_id"], name: "index_pwb_agencies_on_website_id"
  end

  create_table "pwb_auth_audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "website_id"
    t.string "event_type", null: false
    t.string "email"
    t.string "provider"
    t.string "ip_address"
    t.string "user_agent"
    t.string "request_path"
    t.jsonb "metadata", default: {}
    t.string "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_pwb_auth_audit_logs_on_created_at"
    t.index ["email"], name: "index_pwb_auth_audit_logs_on_email"
    t.index ["event_type"], name: "index_pwb_auth_audit_logs_on_event_type"
    t.index ["ip_address"], name: "index_pwb_auth_audit_logs_on_ip_address"
    t.index ["user_id", "event_type"], name: "index_pwb_auth_audit_logs_on_user_id_and_event_type"
    t.index ["user_id"], name: "index_pwb_auth_audit_logs_on_user_id"
    t.index ["website_id", "event_type"], name: "index_pwb_auth_audit_logs_on_website_id_and_event_type"
    t.index ["website_id"], name: "index_pwb_auth_audit_logs_on_website_id"
  end

  create_table "pwb_authorizations", force: :cascade do |t|
    t.bigint "user_id"
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_pwb_authorizations_on_user_id"
  end

  create_table "pwb_clients", id: :serial, force: :cascade do |t|
    t.string "first_names"
    t.string "last_names"
    t.string "client_title"
    t.string "phone_number_primary"
    t.string "phone_number_other"
    t.string "fax"
    t.string "nationality"
    t.string "email"
    t.string "skype"
    t.string "documentation_id"
    t.integer "documentation_type"
    t.integer "user_id"
    t.integer "address_id"
    t.integer "flags", default: 0, null: false
    t.json "details", default: {}
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["documentation_id"], name: "index_pwb_clients_on_documentation_id", unique: true
    t.index ["email"], name: "index_pwb_clients_on_email", unique: true
    t.index ["first_names", "last_names"], name: "index_pwb_clients_on_first_names_and_last_names"
  end

  create_table "pwb_contacts", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "other_names"
    t.integer "title", default: 0
    t.string "primary_phone_number"
    t.string "other_phone_number"
    t.string "fax"
    t.string "nationality"
    t.string "primary_email"
    t.string "other_email"
    t.string "skype_id"
    t.string "facebook_id"
    t.string "linkedin_id"
    t.string "twitter_id"
    t.string "website_url"
    t.string "documentation_id"
    t.integer "documentation_type"
    t.integer "user_id"
    t.integer "primary_address_id"
    t.integer "secondary_address_id"
    t.integer "flags", default: 0, null: false
    t.json "details", default: {}
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "website_id"
    t.index ["documentation_id"], name: "index_pwb_contacts_on_documentation_id"
    t.index ["first_name", "last_name"], name: "index_pwb_contacts_on_first_name_and_last_name"
    t.index ["first_name"], name: "index_pwb_contacts_on_first_name"
    t.index ["last_name"], name: "index_pwb_contacts_on_last_name"
    t.index ["primary_email"], name: "index_pwb_contacts_on_primary_email"
    t.index ["primary_phone_number"], name: "index_pwb_contacts_on_primary_phone_number"
    t.index ["title"], name: "index_pwb_contacts_on_title"
    t.index ["website_id"], name: "index_pwb_contacts_on_website_id"
  end

  create_table "pwb_content_photos", id: :serial, force: :cascade do |t|
    t.integer "content_id"
    t.string "image"
    t.string "description"
    t.string "folder"
    t.integer "file_size"
    t.integer "sort_order"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "block_key"
    t.string "external_url"
    t.index ["content_id"], name: "index_pwb_content_photos_on_content_id"
  end

  create_table "pwb_content_translations", force: :cascade do |t|
    t.integer "content_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "raw"
    t.index ["content_id"], name: "index_pwb_content_translations_on_pwb_content_id"
    t.index ["locale"], name: "index_pwb_content_translations_on_locale"
  end

  create_table "pwb_contents", id: :serial, force: :cascade do |t|
    t.string "key"
    t.string "tag"
    t.string "input_type"
    t.string "status"
    t.integer "last_updated_by_user_id"
    t.integer "sort_order"
    t.string "target_url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "section_key"
    t.string "page_part_key"
    t.integer "website_id"
    t.jsonb "translations", default: {}, null: false
    t.index ["translations"], name: "index_pwb_contents_on_translations", using: :gin
    t.index ["website_id", "key"], name: "index_pwb_contents_on_website_id_and_key", unique: true
    t.index ["website_id"], name: "index_pwb_contents_on_website_id"
  end

  create_table "pwb_features", id: :serial, force: :cascade do |t|
    t.string "feature_key"
    t.integer "prop_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.uuid "realty_asset_id"
    t.index ["feature_key"], name: "index_pwb_features_on_feature_key"
    t.index ["realty_asset_id", "feature_key"], name: "index_pwb_features_on_realty_asset_id_and_feature_key"
    t.index ["realty_asset_id"], name: "index_pwb_features_on_realty_asset_id"
  end

  create_table "pwb_field_keys", id: :serial, force: :cascade do |t|
    t.string "global_key"
    t.string "tag"
    t.boolean "visible", default: true
    t.integer "props_count", default: 0, null: false
    t.boolean "show_in_search_form", default: true
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "pwb_website_id"
    t.integer "sort_order", default: 0
    t.index ["pwb_website_id", "global_key"], name: "index_field_keys_unique_per_website", unique: true
    t.index ["pwb_website_id", "tag"], name: "index_field_keys_on_website_and_tag"
    t.index ["pwb_website_id"], name: "index_pwb_field_keys_on_pwb_website_id"
  end

  create_table "pwb_link_translations", force: :cascade do |t|
    t.integer "link_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "link_title", default: ""
    t.index ["link_id"], name: "index_pwb_link_translations_on_pwb_link_id"
    t.index ["locale"], name: "index_pwb_link_translations_on_locale"
  end

  create_table "pwb_links", id: :serial, force: :cascade do |t|
    t.string "slug"
    t.string "parent_slug"
    t.string "page_slug"
    t.string "icon_class"
    t.string "href_class"
    t.string "href_target"
    t.boolean "is_external", default: false
    t.string "link_url"
    t.string "link_path"
    t.string "link_path_params"
    t.boolean "visible", default: true
    t.boolean "is_deletable", default: false
    t.integer "flags", default: 0, null: false
    t.integer "sort_order", default: 0
    t.integer "placement", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "website_id"
    t.jsonb "translations", default: {}, null: false
    t.index ["flags"], name: "index_pwb_links_on_flags"
    t.index ["page_slug"], name: "index_pwb_links_on_page_slug"
    t.index ["placement"], name: "index_pwb_links_on_placement"
    t.index ["translations"], name: "index_pwb_links_on_translations", using: :gin
    t.index ["website_id", "slug"], name: "index_pwb_links_on_website_id_and_slug", unique: true
    t.index ["website_id"], name: "index_pwb_links_on_website_id"
  end

  create_table "pwb_messages", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.integer "client_id"
    t.string "origin_ip"
    t.string "user_agent"
    t.float "longitude"
    t.float "latitude"
    t.string "locale"
    t.string "host"
    t.string "url"
    t.boolean "delivery_success", default: false
    t.string "delivery_email"
    t.string "origin_email"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "contact_id"
    t.bigint "website_id"
    t.index ["website_id"], name: "index_pwb_messages_on_website_id"
  end

  create_table "pwb_page_contents", force: :cascade do |t|
    t.boolean "is_rails_part", default: false
    t.string "page_part_key"
    t.string "label"
    t.integer "sort_order"
    t.boolean "visible_on_page", default: true
    t.bigint "page_id"
    t.bigint "content_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "website_id"
    t.index ["content_id"], name: "index_pwb_page_contents_on_content_id"
    t.index ["page_id"], name: "index_pwb_page_contents_on_page_id"
    t.index ["website_id"], name: "index_pwb_page_contents_on_website_id"
  end

  create_table "pwb_page_parts", force: :cascade do |t|
    t.boolean "is_rails_part", default: false
    t.boolean "show_in_editor", default: true
    t.integer "order_in_editor"
    t.string "page_part_key"
    t.string "page_slug"
    t.text "template"
    t.json "editor_setup", default: {}
    t.json "block_contents", default: {}
    t.string "theme_name"
    t.string "locale"
    t.integer "flags", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "website_id"
    t.index ["page_part_key", "page_slug", "website_id"], name: "index_page_parts_unique_per_website", unique: true
    t.index ["page_part_key"], name: "index_pwb_page_parts_on_page_part_key"
    t.index ["page_slug"], name: "index_pwb_page_parts_on_page_slug"
    t.index ["website_id"], name: "index_pwb_page_parts_on_website_id"
  end

  create_table "pwb_page_translations", force: :cascade do |t|
    t.integer "page_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "raw_html", default: ""
    t.string "page_title", default: ""
    t.string "link_title", default: ""
    t.index ["locale"], name: "index_pwb_page_translations_on_locale"
    t.index ["page_id"], name: "index_pwb_page_translations_on_pwb_page_id"
  end

  create_table "pwb_pages", id: :serial, force: :cascade do |t|
    t.string "slug"
    t.string "setup_id"
    t.boolean "visible", default: false
    t.integer "last_updated_by_user_id"
    t.integer "flags", default: 0, null: false
    t.json "details", default: {}
    t.integer "sort_order_top_nav", default: 0
    t.integer "sort_order_footer", default: 0
    t.boolean "show_in_top_nav", default: false
    t.boolean "show_in_footer", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "website_id"
    t.jsonb "translations", default: {}, null: false
    t.string "seo_title"
    t.text "meta_description"
    t.index ["flags"], name: "index_pwb_pages_on_flags"
    t.index ["show_in_footer"], name: "index_pwb_pages_on_show_in_footer"
    t.index ["show_in_top_nav"], name: "index_pwb_pages_on_show_in_top_nav"
    t.index ["slug", "website_id"], name: "index_pwb_pages_on_slug_and_website_id", unique: true
    t.index ["translations"], name: "index_pwb_pages_on_translations", using: :gin
    t.index ["website_id"], name: "index_pwb_pages_on_website_id"
  end

  create_table "pwb_prop_photos", id: :serial, force: :cascade do |t|
    t.integer "prop_id"
    t.string "image"
    t.string "description"
    t.string "folder"
    t.integer "file_size"
    t.integer "sort_order"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.uuid "realty_asset_id"
    t.string "external_url"
    t.index ["prop_id"], name: "index_pwb_prop_photos_on_prop_id"
    t.index ["realty_asset_id"], name: "index_pwb_prop_photos_on_realty_asset_id"
  end

  create_table "pwb_prop_translations", force: :cascade do |t|
    t.integer "prop_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title", default: ""
    t.text "description", default: ""
    t.uuid "realty_asset_id"
    t.index ["locale"], name: "index_pwb_prop_translations_on_locale"
    t.index ["prop_id"], name: "index_pwb_prop_translations_on_pwb_prop_id"
    t.index ["realty_asset_id"], name: "index_pwb_prop_translations_on_realty_asset_id"
  end

  create_table "pwb_props", id: :serial, force: :cascade do |t|
    t.string "reference"
    t.integer "year_construction", default: 0, null: false
    t.integer "count_bedrooms", default: 0, null: false
    t.float "count_bathrooms", default: 0.0, null: false
    t.integer "count_toilets", default: 0, null: false
    t.integer "count_garages", default: 0, null: false
    t.float "plot_area", default: 0.0, null: false
    t.float "constructed_area", default: 0.0, null: false
    t.integer "energy_rating"
    t.float "energy_performance"
    t.integer "flags", default: 0, null: false
    t.boolean "furnished", default: false
    t.boolean "sold", default: false
    t.boolean "reserved", default: false
    t.boolean "highlighted", default: false
    t.boolean "archived", default: false
    t.boolean "visible", default: false
    t.boolean "for_rent_short_term", default: false
    t.boolean "for_rent_long_term", default: false
    t.boolean "for_sale", default: false
    t.boolean "hide_map", default: false
    t.boolean "obscure_map", default: false
    t.boolean "portals_enabled", default: false
    t.datetime "deleted_at", precision: nil
    t.datetime "active_from", precision: nil
    t.datetime "available_to_rent_from", precision: nil
    t.datetime "available_to_rent_till", precision: nil
    t.bigint "price_sale_current_cents", default: 0, null: false
    t.string "price_sale_current_currency", default: "EUR", null: false
    t.bigint "price_sale_original_cents", default: 0, null: false
    t.string "price_sale_original_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_current_cents", default: 0, null: false
    t.string "price_rental_monthly_current_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_original_cents", default: 0, null: false
    t.string "price_rental_monthly_original_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_low_season_cents", default: 0, null: false
    t.string "price_rental_monthly_low_season_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_high_season_cents", default: 0, null: false
    t.string "price_rental_monthly_high_season_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_standard_season_cents", default: 0, null: false
    t.string "price_rental_monthly_standard_season_currency", default: "EUR", null: false
    t.integer "commission_cents", default: 0, null: false
    t.string "commission_currency", default: "EUR", null: false
    t.integer "service_charge_yearly_cents", default: 0, null: false
    t.string "service_charge_yearly_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_for_search_cents", default: 0, null: false
    t.string "price_rental_monthly_for_search_currency", default: "EUR", null: false
    t.string "currency"
    t.string "prop_origin_key", default: "", null: false
    t.string "prop_state_key", default: "", null: false
    t.string "prop_type_key", default: "", null: false
    t.string "street_number"
    t.string "street_name"
    t.string "street_address"
    t.string "postal_code"
    t.string "province"
    t.string "city"
    t.string "region"
    t.string "country"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "area_unit", default: 0
    t.integer "website_id"
    t.jsonb "translations", default: {}, null: false
    t.string "seo_title"
    t.text "meta_description"
    t.index ["archived"], name: "index_pwb_props_on_archived"
    t.index ["flags"], name: "index_pwb_props_on_flags"
    t.index ["for_rent_long_term"], name: "index_pwb_props_on_for_rent_long_term"
    t.index ["for_rent_short_term"], name: "index_pwb_props_on_for_rent_short_term"
    t.index ["for_sale"], name: "index_pwb_props_on_for_sale"
    t.index ["highlighted"], name: "index_pwb_props_on_highlighted"
    t.index ["latitude", "longitude"], name: "index_pwb_props_on_latitude_and_longitude"
    t.index ["price_rental_monthly_current_cents"], name: "index_pwb_props_on_price_rental_monthly_current_cents"
    t.index ["price_sale_current_cents"], name: "index_pwb_props_on_price_sale_current_cents"
    t.index ["reference"], name: "index_pwb_props_on_reference"
    t.index ["translations"], name: "index_pwb_props_on_translations", using: :gin
    t.index ["visible"], name: "index_pwb_props_on_visible"
    t.index ["website_id"], name: "index_pwb_props_on_website_id"
  end

  create_table "pwb_realty_assets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "reference"
    t.string "title"
    t.text "description"
    t.integer "year_construction", default: 0
    t.integer "count_bedrooms", default: 0
    t.float "count_bathrooms", default: 0.0
    t.integer "count_toilets", default: 0
    t.integer "count_garages", default: 0
    t.float "plot_area", default: 0.0
    t.float "constructed_area", default: 0.0
    t.integer "energy_rating"
    t.float "energy_performance"
    t.string "street_number"
    t.string "street_name"
    t.string "street_address"
    t.string "postal_code"
    t.string "city"
    t.string "region"
    t.string "country"
    t.float "latitude"
    t.float "longitude"
    t.string "prop_origin_key"
    t.string "prop_state_key"
    t.string "prop_type_key"
    t.integer "website_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "translations", default: {}, null: false
    t.string "slug"
    t.index ["prop_state_key"], name: "index_pwb_realty_assets_on_prop_state_key"
    t.index ["prop_type_key"], name: "index_pwb_realty_assets_on_prop_type_key"
    t.index ["slug"], name: "index_pwb_realty_assets_on_slug", unique: true
    t.index ["translations"], name: "index_pwb_realty_assets_on_translations", using: :gin
    t.index ["website_id", "prop_type_key"], name: "index_pwb_realty_assets_on_website_id_and_prop_type_key"
    t.index ["website_id"], name: "index_pwb_realty_assets_on_website_id"
  end

  create_table "pwb_rental_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "realty_asset_id"
    t.string "reference"
    t.boolean "visible", default: false
    t.boolean "highlighted", default: false
    t.boolean "archived", default: false
    t.boolean "reserved", default: false
    t.boolean "furnished", default: false
    t.boolean "for_rent_short_term", default: false
    t.boolean "for_rent_long_term", default: false
    t.bigint "price_rental_monthly_current_cents", default: 0
    t.string "price_rental_monthly_current_currency", default: "EUR"
    t.bigint "price_rental_monthly_low_season_cents", default: 0
    t.bigint "price_rental_monthly_high_season_cents", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "translations", default: {}, null: false
    t.boolean "active", default: false, null: false
    t.index ["realty_asset_id", "active"], name: "index_pwb_rental_listings_unique_active", unique: true, where: "(active = true)"
    t.index ["realty_asset_id"], name: "index_pwb_rental_listings_on_realty_asset_id"
    t.index ["translations"], name: "index_pwb_rental_listings_on_translations", using: :gin
  end

  create_table "pwb_sale_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "realty_asset_id"
    t.string "reference"
    t.boolean "visible", default: false
    t.boolean "highlighted", default: false
    t.boolean "archived", default: false
    t.boolean "reserved", default: false
    t.boolean "furnished", default: false
    t.bigint "price_sale_current_cents", default: 0
    t.string "price_sale_current_currency", default: "EUR"
    t.bigint "commission_cents", default: 0
    t.string "commission_currency", default: "EUR"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "translations", default: {}, null: false
    t.boolean "active", default: false, null: false
    t.index ["realty_asset_id", "active"], name: "index_pwb_sale_listings_unique_active", unique: true, where: "(active = true)"
    t.index ["realty_asset_id"], name: "index_pwb_sale_listings_on_realty_asset_id"
    t.index ["translations"], name: "index_pwb_sale_listings_on_translations", using: :gin
  end

  create_table "pwb_user_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.string "role", default: "member", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "website_id"], name: "index_user_memberships_on_user_and_website", unique: true
    t.index ["user_id"], name: "index_pwb_user_memberships_on_user_id"
    t.index ["website_id"], name: "index_pwb_user_memberships_on_website_id"
  end

  create_table "pwb_users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at", precision: nil
    t.string "authentication_token"
    t.boolean "admin", default: false
    t.string "first_names"
    t.string "last_names"
    t.string "skype"
    t.string "phone_number_primary"
    t.string "default_client_locale"
    t.string "default_admin_locale"
    t.string "default_currency"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "firebase_uid"
    t.integer "website_id"
    t.index ["confirmation_token"], name: "index_pwb_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_pwb_users_on_email", unique: true
    t.index ["firebase_uid"], name: "index_pwb_users_on_firebase_uid", unique: true
    t.index ["reset_password_token"], name: "index_pwb_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_pwb_users_on_unlock_token", unique: true
    t.index ["website_id"], name: "index_pwb_users_on_website_id"
  end

  create_table "pwb_website_photos", force: :cascade do |t|
    t.string "photo_key"
    t.string "image"
    t.string "description"
    t.string "folder", default: "weebrix"
    t.integer "file_size"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "website_id"
    t.string "external_url"
    t.index ["photo_key"], name: "index_pwb_website_photos_on_photo_key"
    t.index ["website_id"], name: "index_pwb_website_photos_on_website_id"
  end

  create_table "pwb_websites", id: :serial, force: :cascade do |t|
    t.string "analytics_id"
    t.integer "analytics_id_type"
    t.string "company_display_name"
    t.string "email_for_general_contact_form"
    t.string "email_for_property_contact_form"
    t.integer "contact_address_id"
    t.integer "flags", default: 0, null: false
    t.string "theme_name"
    t.string "google_font_name"
    t.json "configuration", default: {}
    t.json "style_variables_for_theme", default: {}
    t.text "sale_price_options_from", default: ["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"], array: true
    t.text "sale_price_options_till", default: ["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"], array: true
    t.text "rent_price_options_from", default: ["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"], array: true
    t.text "rent_price_options_till", default: ["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"], array: true
    t.text "supported_locales", default: ["en-UK"], array: true
    t.text "supported_currencies", default: [], array: true
    t.string "default_client_locale", default: "en-UK"
    t.string "default_admin_locale", default: "en-UK"
    t.string "default_currency", default: "EUR"
    t.integer "default_area_unit", default: 0
    t.json "social_media", default: {}
    t.text "raw_css"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.json "search_config_rent", default: {}
    t.json "search_config_buy", default: {}
    t.json "search_config_landing", default: {}
    t.json "admin_config", default: {}
    t.json "styles_config", default: {}
    t.json "imports_config", default: {}
    t.json "whitelabel_config", default: {}
    t.json "exchange_rates", default: {}
    t.string "favicon_url"
    t.string "main_logo_url"
    t.string "maps_api_key"
    t.string "recaptcha_key"
    t.string "slug"
    t.string "subdomain"
    t.string "custom_domain"
    t.boolean "custom_domain_verified", default: false
    t.datetime "custom_domain_verified_at"
    t.string "custom_domain_verification_token"
    t.boolean "external_image_mode", default: false, null: false
    t.boolean "ntfy_enabled", default: false, null: false
    t.string "ntfy_server_url", default: "https://ntfy.sh"
    t.string "ntfy_topic_prefix"
    t.string "ntfy_access_token"
    t.boolean "ntfy_notify_inquiries", default: true, null: false
    t.boolean "ntfy_notify_listings", default: true, null: false
    t.boolean "ntfy_notify_users", default: false, null: false
    t.boolean "ntfy_notify_security", default: true, null: false
    t.text "default_meta_description"
    t.string "default_seo_title"
    t.index ["custom_domain"], name: "index_pwb_websites_on_custom_domain", unique: true, where: "((custom_domain IS NOT NULL) AND ((custom_domain)::text <> ''::text))"
    t.index ["slug"], name: "index_pwb_websites_on_slug"
    t.index ["subdomain"], name: "index_pwb_websites_on_subdomain", unique: true
  end

  create_table "translations", id: :serial, force: :cascade do |t|
    t.string "locale"
    t.string "key"
    t.text "value"
    t.text "interpolations"
    t.boolean "is_proc", default: false
    t.string "tag"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "pwb_auth_audit_logs", "pwb_users", column: "user_id"
  add_foreign_key "pwb_auth_audit_logs", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_contacts", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_features", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_field_keys", "pwb_websites"
  add_foreign_key "pwb_messages", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_prop_photos", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_prop_translations", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_rental_listings", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_sale_listings", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_user_memberships", "pwb_users", column: "user_id"
  add_foreign_key "pwb_user_memberships", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_website_photos", "pwb_websites", column: "website_id"

  create_view "pwb_properties", materialized: true, sql_definition: <<-SQL
      SELECT a.id,
      a.reference,
      a.website_id,
      a.slug,
      a.year_construction,
      a.count_bedrooms,
      a.count_bathrooms,
      a.count_toilets,
      a.count_garages,
      a.plot_area,
      a.constructed_area,
      a.energy_rating,
      a.energy_performance,
      a.street_number,
      a.street_name,
      a.street_address,
      a.postal_code,
      a.city,
      a.region,
      a.country,
      a.latitude,
      a.longitude,
      a.prop_origin_key,
      a.prop_state_key,
      a.prop_type_key,
      sl.id AS sale_listing_id,
      (COALESCE(sl.visible, false) AND (NOT COALESCE(sl.archived, true))) AS for_sale,
      COALESCE(sl.price_sale_current_cents, (0)::bigint) AS price_sale_current_cents,
      COALESCE(sl.price_sale_current_currency, 'EUR'::character varying) AS price_sale_current_currency,
      COALESCE(sl.commission_cents, (0)::bigint) AS commission_cents,
      COALESCE(sl.commission_currency, 'EUR'::character varying) AS commission_currency,
      COALESCE(sl.reserved, false) AS sale_reserved,
      COALESCE(sl.furnished, false) AS sale_furnished,
      COALESCE(sl.highlighted, false) AS sale_highlighted,
      rl.id AS rental_listing_id,
      (COALESCE(rl.visible, false) AND (NOT COALESCE(rl.archived, true))) AS for_rent,
      COALESCE(rl.for_rent_short_term, false) AS for_rent_short_term,
      COALESCE(rl.for_rent_long_term, false) AS for_rent_long_term,
      COALESCE(rl.price_rental_monthly_current_cents, (0)::bigint) AS price_rental_monthly_current_cents,
      COALESCE(rl.price_rental_monthly_current_currency, 'EUR'::character varying) AS price_rental_monthly_current_currency,
      COALESCE(rl.price_rental_monthly_low_season_cents, (0)::bigint) AS price_rental_monthly_low_season_cents,
      COALESCE(rl.price_rental_monthly_high_season_cents, (0)::bigint) AS price_rental_monthly_high_season_cents,
      COALESCE(rl.reserved, false) AS rental_reserved,
      COALESCE(rl.furnished, false) AS rental_furnished,
      COALESCE(rl.highlighted, false) AS rental_highlighted,
      ((COALESCE(sl.visible, false) AND (NOT COALESCE(sl.archived, true))) OR (COALESCE(rl.visible, false) AND (NOT COALESCE(rl.archived, true)))) AS visible,
      (COALESCE(sl.highlighted, false) OR COALESCE(rl.highlighted, false)) AS highlighted,
      (COALESCE(sl.reserved, false) OR COALESCE(rl.reserved, false)) AS reserved,
      (COALESCE(sl.furnished, false) OR COALESCE(rl.furnished, false)) AS furnished,
          CASE
              WHEN COALESCE(rl.for_rent_short_term, false) THEN LEAST(NULLIF(COALESCE(rl.price_rental_monthly_low_season_cents, (0)::bigint), 0), NULLIF(COALESCE(rl.price_rental_monthly_current_cents, (0)::bigint), 0), NULLIF(COALESCE(rl.price_rental_monthly_high_season_cents, (0)::bigint), 0))
              ELSE COALESCE(rl.price_rental_monthly_current_cents, (0)::bigint)
          END AS price_rental_monthly_for_search_cents,
      COALESCE(sl.price_sale_current_currency, rl.price_rental_monthly_current_currency, 'EUR'::character varying) AS currency,
      a.created_at,
      a.updated_at
     FROM ((pwb_realty_assets a
       LEFT JOIN pwb_sale_listings sl ON (((sl.realty_asset_id = a.id) AND (sl.active = true))))
       LEFT JOIN pwb_rental_listings rl ON (((rl.realty_asset_id = a.id) AND (rl.active = true))));
  SQL
  add_index "pwb_properties", ["count_bathrooms"], name: "index_pwb_properties_on_bathrooms"
  add_index "pwb_properties", ["count_bedrooms"], name: "index_pwb_properties_on_bedrooms"
  add_index "pwb_properties", ["for_rent"], name: "index_pwb_properties_on_for_rent"
  add_index "pwb_properties", ["for_sale"], name: "index_pwb_properties_on_for_sale"
  add_index "pwb_properties", ["highlighted"], name: "index_pwb_properties_on_highlighted"
  add_index "pwb_properties", ["id"], name: "index_pwb_properties_on_id", unique: true
  add_index "pwb_properties", ["latitude", "longitude"], name: "index_pwb_properties_on_lat_lng"
  add_index "pwb_properties", ["price_rental_monthly_current_cents"], name: "index_pwb_properties_on_price_rental_cents"
  add_index "pwb_properties", ["price_sale_current_cents"], name: "index_pwb_properties_on_price_sale_cents"
  add_index "pwb_properties", ["prop_type_key"], name: "index_pwb_properties_on_prop_type"
  add_index "pwb_properties", ["reference"], name: "index_pwb_properties_on_reference"
  add_index "pwb_properties", ["slug"], name: "index_pwb_properties_on_slug"
  add_index "pwb_properties", ["visible"], name: "index_pwb_properties_on_visible"
  add_index "pwb_properties", ["website_id"], name: "index_pwb_properties_on_website_id"

end
