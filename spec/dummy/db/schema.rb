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

ActiveRecord::Schema.define(version: 20170919134945) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "comfy_cms_blocks", id: :serial, force: :cascade do |t|
    t.string "identifier", null: false
    t.text "content"
    t.string "blockable_type"
    t.integer "blockable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blockable_id", "blockable_type"], name: "index_comfy_cms_blocks_on_blockable_id_and_blockable_type"
    t.index ["blockable_type", "blockable_id"], name: "index_comfy_cms_blocks_on_blockable_type_and_blockable_id"
    t.index ["identifier"], name: "index_comfy_cms_blocks_on_identifier"
  end

  create_table "comfy_cms_categories", id: :serial, force: :cascade do |t|
    t.integer "site_id", null: false
    t.string "label", null: false
    t.string "categorized_type", null: false
    t.index ["site_id", "categorized_type", "label"], name: "index_cms_categories_on_site_id_and_cat_type_and_label", unique: true
  end

  create_table "comfy_cms_categorizations", id: :serial, force: :cascade do |t|
    t.integer "category_id", null: false
    t.string "categorized_type", null: false
    t.integer "categorized_id", null: false
    t.index ["category_id", "categorized_type", "categorized_id"], name: "index_cms_categorizations_on_cat_id_and_catd_type_and_catd_id", unique: true
  end

  create_table "comfy_cms_files", id: :serial, force: :cascade do |t|
    t.integer "site_id", null: false
    t.integer "block_id"
    t.string "label", null: false
    t.string "file_file_name", null: false
    t.string "file_content_type", null: false
    t.integer "file_file_size", null: false
    t.string "description", limit: 2048
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "block_id"], name: "index_comfy_cms_files_on_site_id_and_block_id"
    t.index ["site_id", "file_file_name"], name: "index_comfy_cms_files_on_site_id_and_file_file_name"
    t.index ["site_id", "label"], name: "index_comfy_cms_files_on_site_id_and_label"
    t.index ["site_id", "position"], name: "index_comfy_cms_files_on_site_id_and_position"
  end

  create_table "comfy_cms_layouts", id: :serial, force: :cascade do |t|
    t.integer "site_id", null: false
    t.integer "parent_id"
    t.string "app_layout"
    t.string "label", null: false
    t.string "identifier", null: false
    t.text "content"
    t.text "css"
    t.text "js"
    t.integer "position", default: 0, null: false
    t.boolean "is_shared", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "position"], name: "index_comfy_cms_layouts_on_parent_id_and_position"
    t.index ["site_id", "identifier"], name: "index_comfy_cms_layouts_on_site_id_and_identifier", unique: true
  end

  create_table "comfy_cms_pages", id: :serial, force: :cascade do |t|
    t.integer "site_id", null: false
    t.integer "layout_id"
    t.integer "parent_id"
    t.integer "target_page_id"
    t.string "label", null: false
    t.string "slug"
    t.string "full_path", null: false
    t.text "content_cache"
    t.integer "position", default: 0, null: false
    t.integer "children_count", default: 0, null: false
    t.boolean "is_published", default: true, null: false
    t.boolean "is_shared", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "position"], name: "index_comfy_cms_pages_on_parent_id_and_position"
    t.index ["site_id", "full_path"], name: "index_comfy_cms_pages_on_site_id_and_full_path"
  end

  create_table "comfy_cms_revisions", id: :serial, force: :cascade do |t|
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.index ["record_type", "record_id", "created_at"], name: "index_cms_revisions_on_rtype_and_rid_and_created_at"
  end

  create_table "comfy_cms_sites", id: :serial, force: :cascade do |t|
    t.string "label", null: false
    t.string "identifier", null: false
    t.string "hostname", null: false
    t.string "path"
    t.string "locale", default: "en", null: false
    t.boolean "is_mirrored", default: false, null: false
    t.index ["hostname"], name: "index_comfy_cms_sites_on_hostname"
    t.index ["is_mirrored"], name: "index_comfy_cms_sites_on_is_mirrored"
  end

  create_table "comfy_cms_snippets", id: :serial, force: :cascade do |t|
    t.integer "site_id", null: false
    t.string "label", null: false
    t.string "identifier", null: false
    t.text "content"
    t.integer "position", default: 0, null: false
    t.boolean "is_shared", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "identifier"], name: "index_comfy_cms_snippets_on_site_id_and_identifier", unique: true
    t.index ["site_id", "position"], name: "index_comfy_cms_snippets_on_site_id_and_position"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "theme_name"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["documentation_id"], name: "index_pwb_clients_on_documentation_id", unique: true
    t.index ["email"], name: "index_pwb_clients_on_email", unique: true
    t.index ["first_names", "last_names"], name: "index_pwb_clients_on_first_names_and_last_names"
  end

  create_table "pwb_content_photos", id: :serial, force: :cascade do |t|
    t.integer "content_id"
    t.string "image"
    t.string "description"
    t.string "folder"
    t.integer "file_size"
    t.integer "sort_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "block_key"
    t.index ["content_id"], name: "index_pwb_content_photos_on_content_id"
  end

  create_table "pwb_content_translations", force: :cascade do |t|
    t.integer "pwb_content_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "raw"
    t.index ["locale"], name: "index_pwb_content_translations_on_locale"
    t.index ["pwb_content_id"], name: "index_pwb_content_translations_on_pwb_content_id"
  end

  create_table "pwb_contents", id: :serial, force: :cascade do |t|
    t.string "key"
    t.string "tag"
    t.string "input_type"
    t.string "status"
    t.integer "last_updated_by_user_id"
    t.integer "sort_order"
    t.string "target_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "section_key"
    t.string "fragment_key"
    t.index ["key"], name: "index_pwb_contents_on_key", unique: true
  end

  create_table "pwb_features", id: :serial, force: :cascade do |t|
    t.string "feature_key"
    t.integer "prop_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key"], name: "index_pwb_features_on_feature_key"
  end

  create_table "pwb_field_keys", id: :serial, force: :cascade do |t|
    t.string "global_key"
    t.string "tag"
    t.boolean "visible", default: true
    t.integer "props_count", default: 0, null: false
    t.boolean "show_in_search_form", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["global_key"], name: "index_pwb_field_keys_on_global_key", unique: true
  end

  create_table "pwb_link_translations", force: :cascade do |t|
    t.integer "pwb_link_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "link_title", default: ""
    t.index ["locale"], name: "index_pwb_link_translations_on_locale"
    t.index ["pwb_link_id"], name: "index_pwb_link_translations_on_pwb_link_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flags"], name: "index_pwb_links_on_flags"
    t.index ["page_slug"], name: "index_pwb_links_on_page_slug"
    t.index ["placement"], name: "index_pwb_links_on_placement"
    t.index ["slug"], name: "index_pwb_links_on_slug", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pwb_page_contents", force: :cascade do |t|
    t.string "label"
    t.integer "sort_order"
    t.boolean "visible_on_page", default: true
    t.bigint "page_id"
    t.bigint "content_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_pwb_page_contents_on_content_id"
    t.index ["page_id"], name: "index_pwb_page_contents_on_page_id"
  end

  create_table "pwb_page_translations", force: :cascade do |t|
    t.integer "pwb_page_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "raw_html", default: ""
    t.string "page_title", default: ""
    t.string "link_title", default: ""
    t.index ["locale"], name: "index_pwb_page_translations_on_locale"
    t.index ["pwb_page_id"], name: "index_pwb_page_translations_on_pwb_page_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flags"], name: "index_pwb_pages_on_flags"
    t.index ["show_in_footer"], name: "index_pwb_pages_on_show_in_footer"
    t.index ["show_in_top_nav"], name: "index_pwb_pages_on_show_in_top_nav"
    t.index ["slug"], name: "index_pwb_pages_on_slug", unique: true
  end

  create_table "pwb_prop_photos", id: :serial, force: :cascade do |t|
    t.integer "prop_id"
    t.string "image"
    t.string "description"
    t.string "folder"
    t.integer "file_size"
    t.integer "sort_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prop_id"], name: "index_pwb_prop_photos_on_prop_id"
  end

  create_table "pwb_prop_translations", force: :cascade do |t|
    t.integer "pwb_prop_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title", default: ""
    t.text "description", default: ""
    t.index ["locale"], name: "index_pwb_prop_translations_on_locale"
    t.index ["pwb_prop_id"], name: "index_pwb_prop_translations_on_pwb_prop_id"
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
    t.datetime "deleted_at"
    t.datetime "active_from"
    t.datetime "available_to_rent_from"
    t.datetime "available_to_rent_till"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "area_unit", default: 0
    t.index ["archived"], name: "index_pwb_props_on_archived"
    t.index ["flags"], name: "index_pwb_props_on_flags"
    t.index ["for_rent_long_term"], name: "index_pwb_props_on_for_rent_long_term"
    t.index ["for_rent_short_term"], name: "index_pwb_props_on_for_rent_short_term"
    t.index ["for_sale"], name: "index_pwb_props_on_for_sale"
    t.index ["highlighted"], name: "index_pwb_props_on_highlighted"
    t.index ["latitude", "longitude"], name: "index_pwb_props_on_latitude_and_longitude"
    t.index ["price_rental_monthly_current_cents"], name: "index_pwb_props_on_price_rental_monthly_current_cents"
    t.index ["price_sale_current_cents"], name: "index_pwb_props_on_price_sale_current_cents"
    t.index ["reference"], name: "index_pwb_props_on_reference", unique: true
    t.index ["visible"], name: "index_pwb_props_on_visible"
  end

  create_table "pwb_section_translations", force: :cascade do |t|
    t.integer "pwb_section_id", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "page_title", default: ""
    t.string "link_title", default: ""
    t.index ["locale"], name: "index_pwb_section_translations_on_locale"
    t.index ["pwb_section_id"], name: "index_pwb_section_translations_on_pwb_section_id"
  end

  create_table "pwb_sections", id: :serial, force: :cascade do |t|
    t.string "link_key"
    t.string "link_path"
    t.integer "sort_order"
    t.boolean "visible"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "flags", default: 0, null: false
    t.json "details", default: {}
    t.boolean "is_page", default: false
    t.boolean "show_in_top_nav", default: false
    t.boolean "show_in_footer", default: false
    t.string "key"
    t.index ["link_key"], name: "index_pwb_sections_on_link_key", unique: true
  end

  create_table "pwb_users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "authentication_token"
    t.boolean "admin", default: false
    t.string "first_names"
    t.string "last_names"
    t.string "skype"
    t.string "phone_number_primary"
    t.string "default_client_locale"
    t.string "default_admin_locale"
    t.string "default_currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_pwb_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_pwb_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_pwb_users_on_reset_password_token", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "translations", id: :serial, force: :cascade do |t|
    t.string "locale"
    t.string "key"
    t.text "value"
    t.text "interpolations"
    t.boolean "is_proc", default: false
    t.string "tag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
