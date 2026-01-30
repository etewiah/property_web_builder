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

ActiveRecord::Schema[8.1].define(version: 2026_01_30_152045) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "properties", default: {}
    t.datetime "time", precision: nil, null: false
    t.bigint "visit_id"
    t.bigint "website_id", null: false
    t.index ["properties"], name: "index_ahoy_events_on_properties", using: :gin
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
    t.index ["website_id", "name", "time"], name: "index_ahoy_events_on_website_id_and_name_and_time"
    t.index ["website_id", "time"], name: "index_ahoy_events_on_website_id_and_time"
    t.index ["website_id"], name: "index_ahoy_events_on_website_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.text "landing_page"
    t.string "os"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at", precision: nil
    t.bigint "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "website_id", null: false
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token"], name: "index_ahoy_visits_on_visitor_token"
    t.index ["website_id", "started_at"], name: "index_ahoy_visits_on_website_id_and_started_at"
    t.index ["website_id"], name: "index_ahoy_visits_on_website_id"
  end

  create_table "pwb_addresses", id: :serial, force: :cascade do |t|
    t.string "city"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.float "latitude"
    t.float "longitude"
    t.string "postal_code"
    t.string "region"
    t.string "street_address"
    t.string "street_number"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "pwb_agencies", id: :serial, force: :cascade do |t|
    t.string "analytics_id"
    t.integer "analytics_id_type"
    t.text "available_currencies", default: [], array: true
    t.text "available_locales", default: [], array: true
    t.string "company_id"
    t.integer "company_id_type"
    t.string "company_name"
    t.datetime "created_at", precision: nil, null: false
    t.string "default_admin_locale"
    t.string "default_client_locale"
    t.string "default_currency"
    t.json "details", default: {}
    t.string "display_name"
    t.string "email_for_general_contact_form"
    t.string "email_for_property_contact_form"
    t.string "email_primary"
    t.integer "flags", default: 0, null: false
    t.integer "payment_plan_id"
    t.string "phone_number_mobile"
    t.string "phone_number_other"
    t.string "phone_number_primary"
    t.integer "primary_address_id"
    t.text "raw_css"
    t.integer "secondary_address_id"
    t.json "site_configuration", default: {}
    t.integer "site_template_id"
    t.string "skype"
    t.json "social_media", default: {}
    t.text "supported_currencies", default: [], array: true
    t.text "supported_locales", default: [], array: true
    t.string "theme_name"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.integer "website_id"
    t.index ["website_id"], name: "index_pwb_agencies_on_website_id"
  end

  create_table "pwb_ai_generation_requests", force: :cascade do |t|
    t.string "ai_model"
    t.string "ai_provider", default: "anthropic"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "input_data", default: {}
    t.integer "input_tokens"
    t.string "locale", default: "en"
    t.jsonb "output_data", default: {}
    t.integer "output_tokens"
    t.bigint "prop_id"
    t.string "request_type", null: false
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "website_id", null: false
    t.index ["prop_id", "request_type"], name: "index_pwb_ai_generation_requests_on_prop_id_and_request_type"
    t.index ["prop_id"], name: "index_pwb_ai_generation_requests_on_prop_id"
    t.index ["user_id"], name: "index_pwb_ai_generation_requests_on_user_id"
    t.index ["website_id", "request_type"], name: "idx_on_website_id_request_type_fcf3872c0b"
    t.index ["website_id", "status"], name: "index_pwb_ai_generation_requests_on_website_id_and_status"
    t.index ["website_id"], name: "index_pwb_ai_generation_requests_on_website_id"
  end

  create_table "pwb_ai_writing_rules", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0
    t.text "rule_content", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["website_id", "active"], name: "index_pwb_ai_writing_rules_on_website_id_and_active"
    t.index ["website_id"], name: "index_pwb_ai_writing_rules_on_website_id"
  end

  create_table "pwb_auth_audit_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "event_type", null: false
    t.string "failure_reason"
    t.string "ip_address"
    t.jsonb "metadata", default: {}
    t.string "provider"
    t.string "request_path"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.bigint "website_id"
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
    t.datetime "created_at", precision: nil, null: false
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_pwb_authorizations_on_user_id"
  end

  create_table "pwb_client_themes", force: :cascade do |t|
    t.jsonb "color_schema", default: {}
    t.datetime "created_at", null: false
    t.jsonb "default_config", default: {}
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.jsonb "font_schema", default: {}
    t.string "friendly_name", null: false
    t.jsonb "layout_options", default: {}
    t.string "name", null: false
    t.string "preview_image_url"
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0.0"
    t.index ["enabled"], name: "index_pwb_client_themes_on_enabled"
    t.index ["name"], name: "index_pwb_client_themes_on_name", unique: true
  end

  create_table "pwb_clients", id: :serial, force: :cascade do |t|
    t.integer "address_id"
    t.string "client_title"
    t.datetime "created_at", precision: nil, null: false
    t.json "details", default: {}
    t.string "documentation_id"
    t.integer "documentation_type"
    t.string "email"
    t.string "fax"
    t.string "first_names"
    t.integer "flags", default: 0, null: false
    t.string "last_names"
    t.string "nationality"
    t.string "phone_number_other"
    t.string "phone_number_primary"
    t.string "skype"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["documentation_id"], name: "index_pwb_clients_on_documentation_id", unique: true
    t.index ["email"], name: "index_pwb_clients_on_email", unique: true
    t.index ["first_names", "last_names"], name: "index_pwb_clients_on_first_names_and_last_names"
  end

  create_table "pwb_contacts", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.json "details", default: {}
    t.string "documentation_id"
    t.integer "documentation_type"
    t.string "facebook_id"
    t.string "fax"
    t.string "first_name"
    t.integer "flags", default: 0, null: false
    t.string "last_name"
    t.string "linkedin_id"
    t.string "nationality"
    t.string "other_email"
    t.string "other_names"
    t.string "other_phone_number"
    t.integer "primary_address_id"
    t.string "primary_email"
    t.string "primary_phone_number"
    t.integer "secondary_address_id"
    t.string "skype_id"
    t.integer "title", default: 0
    t.string "twitter_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.bigint "website_id"
    t.string "website_url"
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
    t.string "block_key"
    t.integer "content_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "external_url"
    t.integer "file_size"
    t.string "folder"
    t.string "image"
    t.integer "sort_order"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["content_id"], name: "index_pwb_content_photos_on_content_id"
  end

  create_table "pwb_content_translations", force: :cascade do |t|
    t.integer "content_id", null: false
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.text "raw"
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_pwb_content_translations_on_pwb_content_id"
    t.index ["locale"], name: "index_pwb_content_translations_on_locale"
  end

  create_table "pwb_contents", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "input_type"
    t.string "key"
    t.integer "last_updated_by_user_id"
    t.string "page_part_key"
    t.string "section_key"
    t.integer "sort_order"
    t.string "status"
    t.string "tag"
    t.string "target_url"
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "website_id"
    t.index ["translations"], name: "index_pwb_contents_on_translations", using: :gin
    t.index ["website_id", "key"], name: "index_pwb_contents_on_website_id_and_key", unique: true
    t.index ["website_id"], name: "index_pwb_contents_on_website_id"
  end

  create_table "pwb_email_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "body_html", null: false
    t.text "body_text"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "subject", null: false
    t.string "template_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["active"], name: "index_pwb_email_templates_on_active"
    t.index ["template_key"], name: "index_pwb_email_templates_on_template_key"
    t.index ["website_id", "template_key"], name: "index_pwb_email_templates_on_website_id_and_template_key", unique: true
    t.index ["website_id"], name: "index_pwb_email_templates_on_website_id"
  end

  create_table "pwb_features", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "feature_key"
    t.integer "prop_id"
    t.uuid "realty_asset_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["feature_key"], name: "index_pwb_features_on_feature_key"
    t.index ["realty_asset_id", "feature_key"], name: "index_pwb_features_on_realty_asset_id_and_feature_key"
    t.index ["realty_asset_id"], name: "index_pwb_features_on_realty_asset_id"
  end

  create_table "pwb_field_keys", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "global_key"
    t.integer "props_count", default: 0, null: false
    t.bigint "pwb_website_id"
    t.boolean "show_in_search_form", default: true
    t.integer "sort_order", default: 0
    t.string "tag"
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "visible", default: true
    t.index ["pwb_website_id", "global_key"], name: "index_field_keys_unique_per_website", unique: true
    t.index ["pwb_website_id", "tag"], name: "index_field_keys_on_website_and_tag"
    t.index ["pwb_website_id"], name: "index_pwb_field_keys_on_pwb_website_id"
  end

  create_table "pwb_link_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "link_id", null: false
    t.string "link_title", default: ""
    t.string "locale", null: false
    t.datetime "updated_at", null: false
    t.index ["link_id"], name: "index_pwb_link_translations_on_pwb_link_id"
    t.index ["locale"], name: "index_pwb_link_translations_on_locale"
  end

  create_table "pwb_links", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "flags", default: 0, null: false
    t.string "href_class"
    t.string "href_target"
    t.string "icon_class"
    t.boolean "is_deletable", default: false
    t.boolean "is_external", default: false
    t.string "link_path"
    t.string "link_path_params"
    t.string "link_url"
    t.string "page_slug"
    t.string "parent_slug"
    t.integer "placement", default: 0
    t.string "slug"
    t.integer "sort_order", default: 0
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "visible", default: true
    t.integer "website_id"
    t.index ["flags"], name: "index_pwb_links_on_flags"
    t.index ["page_slug"], name: "index_pwb_links_on_page_slug"
    t.index ["placement"], name: "index_pwb_links_on_placement"
    t.index ["translations"], name: "index_pwb_links_on_translations", using: :gin
    t.index ["website_id", "slug"], name: "index_pwb_links_on_website_id_and_slug", unique: true
    t.index ["website_id"], name: "index_pwb_links_on_website_id"
  end

  create_table "pwb_market_reports", force: :cascade do |t|
    t.bigint "ai_generation_request_id"
    t.jsonb "ai_insights", default: {}
    t.jsonb "branding", default: {}
    t.string "city"
    t.jsonb "comparable_properties", default: []
    t.datetime "created_at", null: false
    t.datetime "generated_at"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.jsonb "market_statistics", default: {}
    t.string "postal_code"
    t.decimal "radius_km", precision: 5, scale: 2
    t.string "reference_number"
    t.string "region"
    t.string "report_type", null: false
    t.string "share_token"
    t.datetime "shared_at"
    t.string "status", default: "draft"
    t.jsonb "subject_details", default: {}
    t.uuid "subject_property_id"
    t.string "suggested_price_currency", default: "USD"
    t.integer "suggested_price_high_cents"
    t.integer "suggested_price_low_cents"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "view_count", default: 0
    t.bigint "website_id", null: false
    t.index ["ai_generation_request_id"], name: "index_pwb_market_reports_on_ai_generation_request_id"
    t.index ["share_token"], name: "index_pwb_market_reports_on_share_token", unique: true, where: "(share_token IS NOT NULL)"
    t.index ["status"], name: "index_pwb_market_reports_on_status"
    t.index ["subject_property_id"], name: "index_pwb_market_reports_on_subject_property_id"
    t.index ["user_id"], name: "index_pwb_market_reports_on_user_id"
    t.index ["website_id", "report_type"], name: "index_pwb_market_reports_on_website_id_and_report_type"
    t.index ["website_id"], name: "index_pwb_market_reports_on_website_id"
  end

  create_table "pwb_media", force: :cascade do |t|
    t.string "alt_text"
    t.bigint "byte_size"
    t.string "caption"
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "filename", null: false
    t.bigint "folder_id"
    t.integer "height"
    t.datetime "last_used_at"
    t.integer "sort_order", default: 0
    t.string "source_type"
    t.string "source_url"
    t.string "tags", default: [], array: true
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0
    t.bigint "website_id", null: false
    t.integer "width"
    t.index ["folder_id"], name: "index_pwb_media_on_folder_id"
    t.index ["tags"], name: "index_pwb_media_on_tags", using: :gin
    t.index ["website_id", "content_type"], name: "index_pwb_media_on_website_id_and_content_type"
    t.index ["website_id", "created_at"], name: "index_pwb_media_on_website_id_and_created_at"
    t.index ["website_id", "folder_id"], name: "index_pwb_media_on_website_id_and_folder_id"
    t.index ["website_id"], name: "index_pwb_media_on_website_id"
  end

  create_table "pwb_media_folders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "slug"
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["parent_id"], name: "index_pwb_media_folders_on_parent_id"
    t.index ["website_id", "parent_id"], name: "index_pwb_media_folders_on_website_id_and_parent_id"
    t.index ["website_id", "slug"], name: "index_pwb_media_folders_on_website_id_and_slug", unique: true
    t.index ["website_id"], name: "index_pwb_media_folders_on_website_id"
  end

  create_table "pwb_messages", id: :serial, force: :cascade do |t|
    t.integer "client_id"
    t.integer "contact_id"
    t.text "content"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "delivered_at"
    t.string "delivery_email"
    t.text "delivery_error"
    t.boolean "delivery_success", default: false
    t.string "host"
    t.float "latitude"
    t.string "locale"
    t.float "longitude"
    t.string "origin_email"
    t.string "origin_ip"
    t.boolean "read", default: false, null: false
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.string "user_agent"
    t.bigint "website_id"
    t.index ["website_id"], name: "index_pwb_messages_on_website_id"
  end

  create_table "pwb_page_contents", force: :cascade do |t|
    t.bigint "content_id"
    t.datetime "created_at", precision: nil, null: false
    t.boolean "is_rails_part", default: false
    t.string "label"
    t.bigint "page_id"
    t.string "page_part_key"
    t.bigint "parent_page_content_id"
    t.string "slot_name"
    t.integer "sort_order"
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "visible_on_page", default: true
    t.bigint "website_id"
    t.index ["content_id"], name: "index_pwb_page_contents_on_content_id"
    t.index ["page_id"], name: "index_pwb_page_contents_on_page_id"
    t.index ["parent_page_content_id", "slot_name", "sort_order"], name: "index_pwb_page_contents_on_parent_slot_order"
    t.index ["parent_page_content_id", "slot_name"], name: "index_pwb_page_contents_on_parent_and_slot"
    t.index ["parent_page_content_id"], name: "index_pwb_page_contents_on_parent_page_content_id"
    t.index ["website_id"], name: "index_pwb_page_contents_on_website_id"
  end

  create_table "pwb_page_parts", force: :cascade do |t|
    t.json "block_contents", default: {}
    t.datetime "created_at", precision: nil, null: false
    t.json "editor_setup", default: {}
    t.integer "flags", default: 0, null: false
    t.boolean "is_rails_part", default: false
    t.string "locale"
    t.integer "order_in_editor"
    t.string "page_part_key"
    t.string "page_slug"
    t.boolean "show_in_editor", default: true
    t.text "template"
    t.string "theme_name"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "website_id"
    t.index ["page_part_key", "page_slug", "website_id"], name: "index_page_parts_unique_per_website", unique: true
    t.index ["page_part_key"], name: "index_pwb_page_parts_on_page_part_key"
    t.index ["page_slug"], name: "index_pwb_page_parts_on_page_slug"
    t.index ["website_id"], name: "index_pwb_page_parts_on_website_id"
  end

  create_table "pwb_page_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "link_title", default: ""
    t.string "locale", null: false
    t.integer "page_id", null: false
    t.string "page_title", default: ""
    t.text "raw_html", default: ""
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_pwb_page_translations_on_locale"
    t.index ["page_id"], name: "index_pwb_page_translations_on_pwb_page_id"
  end

  create_table "pwb_pages", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.json "details", default: {}
    t.integer "flags", default: 0, null: false
    t.integer "last_updated_by_user_id"
    t.text "meta_description"
    t.string "seo_title"
    t.string "setup_id"
    t.boolean "show_in_footer", default: false
    t.boolean "show_in_top_nav", default: false
    t.string "slug"
    t.integer "sort_order_footer", default: 0
    t.integer "sort_order_top_nav", default: 0
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "visible", default: false
    t.integer "website_id"
    t.index ["flags"], name: "index_pwb_pages_on_flags"
    t.index ["show_in_footer"], name: "index_pwb_pages_on_show_in_footer"
    t.index ["show_in_top_nav"], name: "index_pwb_pages_on_show_in_top_nav"
    t.index ["slug", "website_id"], name: "index_pwb_pages_on_slug_and_website_id", unique: true
    t.index ["translations"], name: "index_pwb_pages_on_translations", using: :gin
    t.index ["website_id"], name: "index_pwb_pages_on_website_id"
  end

  create_table "pwb_plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "billing_interval", default: "month", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "display_name", null: false
    t.jsonb "features", default: [], null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents", default: 0, null: false
    t.string "price_currency", default: "USD", null: false
    t.integer "property_limit"
    t.boolean "public", default: true, null: false
    t.string "slug", null: false
    t.integer "trial_days", default: 14, null: false
    t.string "trial_unit", default: "days"
    t.integer "trial_value", default: 14
    t.datetime "updated_at", null: false
    t.integer "user_limit"
    t.index ["active", "position"], name: "index_pwb_plans_on_active_and_position"
    t.index ["slug"], name: "index_pwb_plans_on_slug", unique: true
  end

  create_table "pwb_price_guesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "actual_price_cents", null: false
    t.string "actual_price_currency", default: "EUR"
    t.datetime "created_at", null: false
    t.bigint "guessed_price_cents", null: false
    t.string "guessed_price_currency", default: "EUR"
    t.uuid "listing_id", null: false
    t.string "listing_type", null: false
    t.decimal "percentage_diff", precision: 8, scale: 2
    t.integer "score", default: 0
    t.datetime "updated_at", null: false
    t.string "visitor_token", null: false
    t.bigint "website_id", null: false
    t.index ["listing_type", "listing_id", "score"], name: "index_price_guesses_on_listing_and_score"
    t.index ["listing_type", "listing_id", "visitor_token"], name: "index_price_guesses_on_listing_and_visitor", unique: true
    t.index ["listing_type", "listing_id"], name: "index_pwb_price_guesses_on_listing"
    t.index ["website_id"], name: "index_pwb_price_guesses_on_website_id"
  end

  create_table "pwb_prop_photos", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "external_url"
    t.integer "file_size"
    t.string "folder"
    t.string "image"
    t.integer "prop_id"
    t.uuid "realty_asset_id"
    t.integer "sort_order"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["prop_id"], name: "index_pwb_prop_photos_on_prop_id"
    t.index ["realty_asset_id"], name: "index_pwb_prop_photos_on_realty_asset_id"
  end

  create_table "pwb_prop_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: ""
    t.string "locale", null: false
    t.integer "prop_id", null: false
    t.uuid "realty_asset_id"
    t.string "title", default: ""
    t.datetime "updated_at", null: false
    t.index ["locale"], name: "index_pwb_prop_translations_on_locale"
    t.index ["prop_id"], name: "index_pwb_prop_translations_on_pwb_prop_id"
    t.index ["realty_asset_id"], name: "index_pwb_prop_translations_on_realty_asset_id"
  end

  create_table "pwb_props", id: :serial, force: :cascade do |t|
    t.datetime "active_from", precision: nil
    t.boolean "archived", default: false
    t.integer "area_unit", default: 0
    t.datetime "available_to_rent_from", precision: nil
    t.datetime "available_to_rent_till", precision: nil
    t.string "city"
    t.integer "commission_cents", default: 0, null: false
    t.string "commission_currency", default: "EUR", null: false
    t.float "constructed_area", default: 0.0, null: false
    t.float "count_bathrooms", default: 0.0, null: false
    t.integer "count_bedrooms", default: 0, null: false
    t.integer "count_garages", default: 0, null: false
    t.integer "count_toilets", default: 0, null: false
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.string "currency"
    t.datetime "deleted_at", precision: nil
    t.float "energy_performance"
    t.integer "energy_rating"
    t.integer "flags", default: 0, null: false
    t.boolean "for_rent_long_term", default: false
    t.boolean "for_rent_short_term", default: false
    t.boolean "for_sale", default: false
    t.boolean "furnished", default: false
    t.boolean "hide_map", default: false
    t.boolean "highlighted", default: false
    t.float "latitude"
    t.float "longitude"
    t.text "meta_description"
    t.boolean "obscure_map", default: false
    t.float "plot_area", default: 0.0, null: false
    t.boolean "portals_enabled", default: false
    t.string "postal_code"
    t.integer "price_rental_monthly_current_cents", default: 0, null: false
    t.string "price_rental_monthly_current_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_for_search_cents", default: 0, null: false
    t.string "price_rental_monthly_for_search_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_high_season_cents", default: 0, null: false
    t.string "price_rental_monthly_high_season_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_low_season_cents", default: 0, null: false
    t.string "price_rental_monthly_low_season_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_original_cents", default: 0, null: false
    t.string "price_rental_monthly_original_currency", default: "EUR", null: false
    t.integer "price_rental_monthly_standard_season_cents", default: 0, null: false
    t.string "price_rental_monthly_standard_season_currency", default: "EUR", null: false
    t.bigint "price_sale_current_cents", default: 0, null: false
    t.string "price_sale_current_currency", default: "EUR", null: false
    t.bigint "price_sale_original_cents", default: 0, null: false
    t.string "price_sale_original_currency", default: "EUR", null: false
    t.string "prop_origin_key", default: "", null: false
    t.string "prop_state_key", default: "", null: false
    t.string "prop_type_key", default: "", null: false
    t.string "province"
    t.string "reference"
    t.string "region"
    t.boolean "reserved", default: false
    t.string "seo_title"
    t.integer "service_charge_yearly_cents", default: 0, null: false
    t.string "service_charge_yearly_currency", default: "EUR", null: false
    t.boolean "sold", default: false
    t.string "street_address"
    t.string "street_name"
    t.string "street_number"
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "visible", default: false
    t.integer "website_id"
    t.integer "year_construction", default: 0, null: false
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
    t.string "city"
    t.float "constructed_area", default: 0.0
    t.float "count_bathrooms", default: 0.0
    t.integer "count_bedrooms", default: 0
    t.integer "count_garages", default: 0
    t.integer "count_toilets", default: 0
    t.string "country"
    t.datetime "created_at", null: false
    t.text "description"
    t.float "energy_performance"
    t.integer "energy_rating"
    t.float "latitude"
    t.float "longitude"
    t.float "plot_area", default: 0.0
    t.string "postal_code"
    t.string "prop_origin_key"
    t.integer "prop_photos_count", default: 0, null: false
    t.string "prop_state_key"
    t.string "prop_type_key"
    t.string "reference"
    t.string "region"
    t.string "slug"
    t.string "street_address"
    t.string "street_name"
    t.string "street_number"
    t.string "title"
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "website_id"
    t.integer "year_construction", default: 0
    t.index ["prop_photos_count"], name: "index_pwb_realty_assets_on_prop_photos_count"
    t.index ["prop_state_key"], name: "index_pwb_realty_assets_on_prop_state_key"
    t.index ["prop_type_key"], name: "index_pwb_realty_assets_on_prop_type_key"
    t.index ["slug"], name: "index_pwb_realty_assets_on_slug", unique: true
    t.index ["translations"], name: "index_pwb_realty_assets_on_translations", using: :gin
    t.index ["website_id", "prop_type_key"], name: "index_pwb_realty_assets_on_website_id_and_prop_type_key"
    t.index ["website_id"], name: "index_pwb_realty_assets_on_website_id"
  end

  create_table "pwb_rental_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.boolean "archived", default: false
    t.datetime "created_at", null: false
    t.boolean "for_rent_long_term", default: false
    t.boolean "for_rent_short_term", default: false
    t.boolean "furnished", default: false
    t.boolean "game_enabled", default: false
    t.integer "game_shares_count", default: 0
    t.string "game_token"
    t.integer "game_views_count", default: 0
    t.boolean "highlighted", default: false
    t.boolean "noindex", default: false, null: false
    t.bigint "price_rental_monthly_current_cents", default: 0
    t.string "price_rental_monthly_current_currency", default: "EUR"
    t.bigint "price_rental_monthly_high_season_cents", default: 0
    t.bigint "price_rental_monthly_low_season_cents", default: 0
    t.uuid "realty_asset_id"
    t.string "reference"
    t.boolean "reserved", default: false
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: false
    t.index ["game_token"], name: "index_pwb_rental_listings_on_game_token", unique: true, where: "(game_token IS NOT NULL)"
    t.index ["noindex"], name: "index_pwb_rental_listings_on_noindex"
    t.index ["realty_asset_id", "active"], name: "index_pwb_rental_listings_unique_active", unique: true, where: "(active = true)"
    t.index ["realty_asset_id"], name: "index_pwb_rental_listings_on_realty_asset_id"
    t.index ["translations"], name: "index_pwb_rental_listings_on_translations", using: :gin
  end

  create_table "pwb_sale_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.boolean "archived", default: false
    t.bigint "commission_cents", default: 0
    t.string "commission_currency", default: "EUR"
    t.datetime "created_at", null: false
    t.boolean "furnished", default: false
    t.boolean "game_enabled", default: false
    t.integer "game_shares_count", default: 0
    t.string "game_token"
    t.integer "game_views_count", default: 0
    t.boolean "highlighted", default: false
    t.boolean "noindex", default: false, null: false
    t.bigint "price_sale_current_cents", default: 0
    t.string "price_sale_current_currency", default: "EUR"
    t.uuid "realty_asset_id"
    t.string "reference"
    t.boolean "reserved", default: false
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: false
    t.index ["game_token"], name: "index_pwb_sale_listings_on_game_token", unique: true, where: "(game_token IS NOT NULL)"
    t.index ["noindex"], name: "index_pwb_sale_listings_on_noindex"
    t.index ["realty_asset_id", "active"], name: "index_pwb_sale_listings_unique_active", unique: true, where: "(active = true)"
    t.index ["realty_asset_id"], name: "index_pwb_sale_listings_on_realty_asset_id"
    t.index ["translations"], name: "index_pwb_sale_listings_on_translations", using: :gin
  end

  create_table "pwb_saved_properties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_price_cents"
    t.string "email", null: false
    t.string "external_reference", null: false
    t.string "manage_token", null: false
    t.text "notes"
    t.integer "original_price_cents"
    t.datetime "price_changed_at"
    t.jsonb "property_data", default: {}, null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["email", "provider", "external_reference"], name: "index_saved_properties_unique_per_email", unique: true
    t.index ["email"], name: "index_pwb_saved_properties_on_email"
    t.index ["manage_token"], name: "index_pwb_saved_properties_on_manage_token", unique: true
    t.index ["website_id", "email"], name: "index_pwb_saved_properties_on_website_id_and_email"
    t.index ["website_id", "provider", "external_reference"], name: "index_saved_properties_on_provider_ref"
    t.index ["website_id"], name: "index_pwb_saved_properties_on_website_id"
  end

  create_table "pwb_saved_searches", force: :cascade do |t|
    t.integer "alert_frequency", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "email_verified", default: false, null: false
    t.boolean "enabled", default: true, null: false
    t.integer "last_result_count", default: 0
    t.datetime "last_run_at"
    t.string "manage_token", null: false
    t.string "name"
    t.jsonb "search_criteria", default: {}, null: false
    t.jsonb "seen_property_refs", default: [], null: false
    t.string "unsubscribe_token", null: false
    t.datetime "updated_at", null: false
    t.string "verification_token"
    t.datetime "verified_at"
    t.bigint "website_id", null: false
    t.index ["email"], name: "index_pwb_saved_searches_on_email"
    t.index ["manage_token"], name: "index_pwb_saved_searches_on_manage_token", unique: true
    t.index ["unsubscribe_token"], name: "index_pwb_saved_searches_on_unsubscribe_token", unique: true
    t.index ["verification_token"], name: "index_pwb_saved_searches_on_verification_token", unique: true
    t.index ["website_id", "email"], name: "index_pwb_saved_searches_on_website_id_and_email"
    t.index ["website_id", "enabled", "alert_frequency"], name: "index_saved_searches_for_alerts"
    t.index ["website_id"], name: "index_pwb_saved_searches_on_website_id"
  end

  create_table "pwb_scraped_properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "connector_used"
    t.datetime "created_at", null: false
    t.jsonb "extracted_data", default: {}
    t.jsonb "extracted_images", default: []
    t.string "import_status", default: "pending"
    t.datetime "imported_at"
    t.text "raw_html"
    t.uuid "realty_asset_id"
    t.string "scrape_error_message"
    t.string "scrape_method"
    t.boolean "scrape_successful", default: false
    t.text "script_json"
    t.string "source_host"
    t.string "source_portal"
    t.string "source_url", null: false
    t.string "source_url_normalized"
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["import_status"], name: "index_pwb_scraped_properties_on_import_status"
    t.index ["realty_asset_id"], name: "index_pwb_scraped_properties_on_realty_asset_id"
    t.index ["source_url_normalized"], name: "index_pwb_scraped_properties_on_source_url_normalized"
    t.index ["website_id", "source_host"], name: "index_pwb_scraped_properties_on_website_id_and_source_host"
    t.index ["website_id"], name: "index_pwb_scraped_properties_on_website_id"
  end

  create_table "pwb_search_alerts", force: :cascade do |t|
    t.datetime "clicked_at"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "email_status"
    t.text "error_message"
    t.jsonb "new_properties", default: [], null: false
    t.datetime "opened_at"
    t.integer "properties_count", default: 0, null: false
    t.bigint "saved_search_id", null: false
    t.datetime "sent_at"
    t.integer "total_results_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["saved_search_id", "created_at"], name: "index_pwb_search_alerts_on_saved_search_id_and_created_at"
    t.index ["saved_search_id"], name: "index_pwb_search_alerts_on_saved_search_id"
    t.index ["sent_at"], name: "index_pwb_search_alerts_on_sent_at"
  end

  create_table "pwb_search_filter_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_code"
    t.string "filter_type", null: false
    t.string "global_key", null: false
    t.string "icon"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "parent_id"
    t.boolean "show_in_search", default: true, null: false
    t.integer "sort_order", default: 0, null: false
    t.jsonb "translations", default: {}, null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.bigint "website_id", null: false
    t.index ["parent_id"], name: "index_pwb_search_filter_options_on_parent_id"
    t.index ["website_id", "external_code"], name: "index_search_filter_options_on_external_code", where: "(external_code IS NOT NULL)"
    t.index ["website_id", "filter_type", "global_key"], name: "index_search_filter_options_unique_key", unique: true
    t.index ["website_id", "filter_type", "sort_order"], name: "index_search_filter_options_on_order"
    t.index ["website_id", "filter_type"], name: "index_search_filter_options_on_type"
    t.index ["website_id"], name: "index_pwb_search_filter_options_on_website_id"
  end

  create_table "pwb_shard_audit_logs", force: :cascade do |t|
    t.string "changed_by_email", null: false
    t.datetime "created_at", null: false
    t.string "new_shard_name", null: false
    t.string "notes"
    t.string "old_shard_name"
    t.string "status", default: "completed", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["changed_by_email"], name: "index_pwb_shard_audit_logs_on_changed_by_email"
    t.index ["created_at"], name: "index_pwb_shard_audit_logs_on_created_at"
    t.index ["status"], name: "index_pwb_shard_audit_logs_on_status"
    t.index ["website_id"], name: "index_pwb_shard_audit_logs_on_website_id"
  end

  create_table "pwb_social_media_posts", force: :cascade do |t|
    t.bigint "ai_generation_request_id"
    t.string "call_to_action"
    t.text "caption", null: false
    t.integer "comments_count", default: 0
    t.datetime "created_at", null: false
    t.text "hashtags"
    t.integer "likes_count", default: 0
    t.string "link_url"
    t.string "platform", null: false
    t.string "post_type", null: false
    t.bigint "postable_id"
    t.string "postable_type"
    t.integer "reach_count", default: 0
    t.datetime "scheduled_at"
    t.jsonb "selected_photos", default: []
    t.integer "shares_count", default: 0
    t.string "status", default: "draft"
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["ai_generation_request_id"], name: "index_pwb_social_media_posts_on_ai_generation_request_id"
    t.index ["postable_type", "postable_id"], name: "index_pwb_social_media_posts_on_postable"
    t.index ["postable_type", "postable_id"], name: "index_pwb_social_media_posts_on_postable_type_and_postable_id"
    t.index ["scheduled_at"], name: "index_pwb_social_media_posts_on_scheduled_at"
    t.index ["status"], name: "index_pwb_social_media_posts_on_status"
    t.index ["website_id", "platform"], name: "index_pwb_social_media_posts_on_website_id_and_platform"
    t.index ["website_id"], name: "index_pwb_social_media_posts_on_website_id"
  end

  create_table "pwb_social_media_templates", force: :cascade do |t|
    t.boolean "active", default: true
    t.text "caption_template", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.text "hashtag_template"
    t.jsonb "image_preferences", default: {}
    t.boolean "is_default", default: false
    t.string "name", null: false
    t.string "platform", null: false
    t.string "post_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["website_id", "platform", "category"], name: "idx_on_website_id_platform_category_c9f0f62b45"
    t.index ["website_id"], name: "index_pwb_social_media_templates_on_website_id"
  end

  create_table "pwb_subdomains", force: :cascade do |t|
    t.string "aasm_state", default: "available", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "reserved_at"
    t.string "reserved_by_email"
    t.datetime "reserved_until"
    t.datetime "updated_at", null: false
    t.bigint "website_id"
    t.index ["aasm_state", "name"], name: "index_pwb_subdomains_on_aasm_state_and_name"
    t.index ["aasm_state"], name: "index_pwb_subdomains_on_aasm_state"
    t.index ["name"], name: "index_pwb_subdomains_on_name", unique: true
    t.index ["reserved_by_email"], name: "index_subdomains_unique_reserved_email", unique: true, where: "(((aasm_state)::text = 'reserved'::text) AND (reserved_by_email IS NOT NULL))"
    t.index ["website_id"], name: "index_pwb_subdomains_on_website_id"
  end

  create_table "pwb_subscription_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "subscription_id", null: false
    t.index ["event_type"], name: "index_pwb_subscription_events_on_event_type"
    t.index ["subscription_id", "created_at"], name: "idx_on_subscription_id_created_at_3fabb76699"
    t.index ["subscription_id"], name: "index_pwb_subscription_events_on_subscription_id"
  end

  create_table "pwb_subscriptions", force: :cascade do |t|
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.datetime "current_period_starts_at"
    t.string "external_customer_id"
    t.string "external_id"
    t.string "external_provider"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "plan_id", null: false
    t.string "status", default: "trialing", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["current_period_ends_at"], name: "index_pwb_subscriptions_on_current_period_ends_at"
    t.index ["external_id"], name: "index_pwb_subscriptions_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["plan_id"], name: "index_pwb_subscriptions_on_plan_id"
    t.index ["status"], name: "index_pwb_subscriptions_on_status"
    t.index ["trial_ends_at"], name: "index_pwb_subscriptions_on_trial_ends_at"
    t.index ["website_id"], name: "index_pwb_subscriptions_on_website_unique", unique: true
  end

  create_table "pwb_support_tickets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "assigned_at"
    t.bigint "assigned_to_id"
    t.string "category", limit: 50
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description"
    t.datetime "first_response_at"
    t.datetime "last_message_at"
    t.boolean "last_message_from_platform", default: false
    t.integer "message_count", default: 0
    t.integer "priority", default: 1, null: false
    t.datetime "resolved_at"
    t.boolean "sla_resolution_breached", default: false
    t.datetime "sla_resolution_due_at"
    t.boolean "sla_response_breached", default: false
    t.datetime "sla_response_due_at"
    t.datetime "sla_warning_sent_at"
    t.integer "status", default: 0, null: false
    t.string "subject", limit: 255, null: false
    t.string "ticket_number", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["assigned_to_id", "status"], name: "index_pwb_support_tickets_on_assigned_to_id_and_status"
    t.index ["assigned_to_id"], name: "index_pwb_support_tickets_on_assigned_to_id"
    t.index ["creator_id"], name: "index_pwb_support_tickets_on_creator_id"
    t.index ["priority"], name: "index_pwb_support_tickets_on_priority"
    t.index ["sla_resolution_due_at"], name: "index_pwb_support_tickets_on_sla_resolution_due_at"
    t.index ["sla_response_breached", "status"], name: "idx_tickets_sla_response_breach_status"
    t.index ["sla_response_due_at"], name: "index_pwb_support_tickets_on_sla_response_due_at"
    t.index ["status"], name: "index_pwb_support_tickets_on_status"
    t.index ["ticket_number"], name: "index_pwb_support_tickets_on_ticket_number", unique: true
    t.index ["website_id", "created_at"], name: "index_pwb_support_tickets_on_website_id_and_created_at"
    t.index ["website_id", "status"], name: "index_pwb_support_tickets_on_website_id_and_status"
    t.index ["website_id"], name: "index_pwb_support_tickets_on_website_id"
  end

  create_table "pwb_tenant_settings", force: :cascade do |t|
    t.jsonb "configuration", default: {}
    t.datetime "created_at", null: false
    t.text "default_available_themes", default: [], array: true
    t.string "singleton_key", default: "default", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_key"], name: "index_pwb_tenant_settings_on_singleton_key", unique: true
  end

  create_table "pwb_testimonials", force: :cascade do |t|
    t.string "author_name", null: false
    t.bigint "author_photo_id"
    t.string "author_role"
    t.datetime "created_at", null: false
    t.boolean "featured", default: false, null: false
    t.integer "position", default: 0, null: false
    t.text "quote", null: false
    t.integer "rating"
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.bigint "website_id", null: false
    t.index ["author_photo_id"], name: "index_pwb_testimonials_on_author_photo_id"
    t.index ["position"], name: "index_pwb_testimonials_on_position"
    t.index ["visible"], name: "index_pwb_testimonials_on_visible"
    t.index ["website_id"], name: "index_pwb_testimonials_on_website_id"
  end

  create_table "pwb_ticket_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.boolean "from_platform_admin", default: false
    t.boolean "internal_note", default: false
    t.string "status_changed_from", limit: 50
    t.string "status_changed_to", limit: 50
    t.uuid "support_ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.index ["support_ticket_id", "created_at"], name: "index_pwb_ticket_messages_on_support_ticket_id_and_created_at"
    t.index ["support_ticket_id"], name: "index_pwb_ticket_messages_on_support_ticket_id"
    t.index ["user_id"], name: "index_pwb_ticket_messages_on_user_id"
    t.index ["website_id", "created_at"], name: "index_pwb_ticket_messages_on_website_id_and_created_at"
    t.index ["website_id"], name: "index_pwb_ticket_messages_on_website_id"
  end

  create_table "pwb_user_memberships", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.index ["user_id", "website_id"], name: "index_user_memberships_on_user_and_website", unique: true
    t.index ["user_id"], name: "index_pwb_user_memberships_on_user_id"
    t.index ["website_id"], name: "index_pwb_user_memberships_on_website_id"
  end

  create_table "pwb_users", id: :serial, force: :cascade do |t|
    t.boolean "admin", default: false
    t.string "authentication_token"
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "default_admin_locale"
    t.string "default_client_locale"
    t.string "default_currency"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "firebase_uid"
    t.string "first_names"
    t.string "last_names"
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "locked_at", precision: nil
    t.jsonb "metadata", default: {}, null: false
    t.datetime "onboarding_completed_at"
    t.datetime "onboarding_started_at"
    t.string "onboarding_state", default: "active", null: false
    t.integer "onboarding_step", default: 0
    t.string "phone_number_primary"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "signup_token"
    t.datetime "signup_token_expires_at"
    t.datetime "site_admin_onboarding_completed_at"
    t.string "skype"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "website_id"
    t.index "((metadata ->> 'zoho_lead_id'::text))", name: "index_pwb_users_on_zoho_lead_id", where: "((metadata ->> 'zoho_lead_id'::text) IS NOT NULL)"
    t.index ["confirmation_token"], name: "index_pwb_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_pwb_users_on_email", unique: true
    t.index ["firebase_uid"], name: "index_pwb_users_on_firebase_uid", unique: true
    t.index ["onboarding_state"], name: "index_pwb_users_on_onboarding_state"
    t.index ["reset_password_token"], name: "index_pwb_users_on_reset_password_token", unique: true
    t.index ["signup_token"], name: "index_pwb_users_on_signup_token", unique: true
    t.index ["site_admin_onboarding_completed_at"], name: "index_pwb_users_on_site_admin_onboarding_completed_at"
    t.index ["unlock_token"], name: "index_pwb_users_on_unlock_token", unique: true
    t.index ["website_id"], name: "index_pwb_users_on_website_id"
  end

  create_table "pwb_website_integrations", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "credentials"
    t.boolean "enabled", default: true
    t.datetime "last_error_at"
    t.text "last_error_message"
    t.datetime "last_used_at"
    t.string "provider", null: false
    t.jsonb "settings", default: {}
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["website_id", "category", "provider"], name: "idx_website_integrations_unique_provider", unique: true
    t.index ["website_id", "category"], name: "index_pwb_website_integrations_on_website_id_and_category"
    t.index ["website_id", "enabled"], name: "index_pwb_website_integrations_on_website_id_and_enabled"
    t.index ["website_id"], name: "index_pwb_website_integrations_on_website_id"
  end

  create_table "pwb_website_photos", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "external_url"
    t.integer "file_size"
    t.string "folder", default: "weebrix"
    t.string "image"
    t.string "photo_key"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "website_id"
    t.index ["photo_key"], name: "index_pwb_website_photos_on_photo_key"
    t.index ["website_id"], name: "index_pwb_website_photos_on_website_id"
  end

  create_table "pwb_websites", id: :serial, force: :cascade do |t|
    t.json "admin_config", default: {}
    t.string "analytics_id"
    t.integer "analytics_id_type"
    t.text "available_currencies", default: [], array: true
    t.text "available_themes", array: true
    t.jsonb "client_theme_config", default: {}
    t.string "client_theme_name"
    t.string "company_display_name"
    t.text "compiled_palette_css"
    t.json "configuration", default: {}
    t.integer "contact_address_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "custom_domain"
    t.string "custom_domain_verification_token"
    t.boolean "custom_domain_verified", default: false
    t.datetime "custom_domain_verified_at"
    t.string "dark_mode_setting", default: "light_only", null: false
    t.string "default_admin_locale", default: "en-UK"
    t.integer "default_area_unit", default: 0
    t.string "default_client_locale", default: "en-UK"
    t.string "default_currency", default: "EUR"
    t.text "default_meta_description"
    t.string "default_seo_title"
    t.datetime "demo_last_reset_at"
    t.boolean "demo_mode", default: false, null: false
    t.interval "demo_reset_interval", default: "PT24H"
    t.string "demo_seed_pack"
    t.string "email_for_general_contact_form"
    t.string "email_for_property_contact_form"
    t.string "email_verification_token"
    t.datetime "email_verification_token_expires_at"
    t.datetime "email_verified_at"
    t.json "exchange_rates", default: {}
    t.json "external_feed_config", default: {}
    t.boolean "external_feed_enabled", default: false, null: false
    t.string "external_feed_provider"
    t.boolean "external_image_mode", default: false, null: false
    t.string "favicon_url"
    t.integer "flags", default: 0, null: false
    t.string "google_font_name"
    t.json "imports_config", default: {}
    t.string "main_logo_url"
    t.string "maps_api_key"
    t.string "ntfy_access_token"
    t.boolean "ntfy_enabled", default: false, null: false
    t.boolean "ntfy_notify_inquiries", default: true, null: false
    t.boolean "ntfy_notify_listings", default: true, null: false
    t.boolean "ntfy_notify_security", default: true, null: false
    t.boolean "ntfy_notify_users", default: false, null: false
    t.string "ntfy_server_url", default: "https://ntfy.sh"
    t.string "ntfy_topic_prefix"
    t.string "owner_email"
    t.datetime "palette_compiled_at"
    t.string "palette_mode", default: "dynamic", null: false
    t.datetime "provisioning_completed_at"
    t.text "provisioning_error"
    t.datetime "provisioning_failed_at"
    t.datetime "provisioning_started_at"
    t.string "provisioning_state", default: "live", null: false
    t.text "raw_css"
    t.integer "realty_assets_count", default: 0, null: false
    t.string "recaptcha_key"
    t.string "rendering_mode", default: "rails", null: false
    t.text "rent_price_options_from", default: ["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"], array: true
    t.text "rent_price_options_till", default: ["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"], array: true
    t.text "sale_price_options_from", default: ["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"], array: true
    t.text "sale_price_options_till", default: ["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"], array: true
    t.jsonb "search_config", default: {}, null: false
    t.json "search_config_buy", default: {}
    t.json "search_config_landing", default: {}
    t.json "search_config_rent", default: {}
    t.string "seed_pack_name"
    t.string "selected_palette"
    t.string "shard_name", default: "default"
    t.string "site_type"
    t.string "slug"
    t.json "social_media", default: {}
    t.json "style_variables_for_theme", default: {}
    t.json "styles_config", default: {}
    t.string "subdomain"
    t.text "supported_currencies", default: [], array: true
    t.text "supported_locales", default: ["en-UK"], array: true
    t.string "theme_name"
    t.datetime "updated_at", precision: nil, null: false
    t.json "whitelabel_config", default: {}
    t.index ["custom_domain"], name: "index_pwb_websites_on_custom_domain", unique: true, where: "((custom_domain IS NOT NULL) AND ((custom_domain)::text <> ''::text))"
    t.index ["dark_mode_setting"], name: "index_pwb_websites_on_dark_mode_setting"
    t.index ["demo_mode", "shard_name"], name: "index_pwb_websites_on_demo_mode_and_shard_name"
    t.index ["email_verification_token"], name: "index_pwb_websites_on_email_verification_token", unique: true, where: "(email_verification_token IS NOT NULL)"
    t.index ["external_feed_enabled"], name: "index_pwb_websites_on_external_feed_enabled"
    t.index ["external_feed_provider"], name: "index_pwb_websites_on_external_feed_provider"
    t.index ["palette_mode"], name: "index_pwb_websites_on_palette_mode"
    t.index ["provisioning_state"], name: "index_pwb_websites_on_provisioning_state"
    t.index ["realty_assets_count"], name: "index_pwb_websites_on_realty_assets_count"
    t.index ["rendering_mode"], name: "index_pwb_websites_on_rendering_mode"
    t.index ["search_config"], name: "index_pwb_websites_on_search_config", using: :gin
    t.index ["selected_palette"], name: "index_pwb_websites_on_selected_palette"
    t.index ["site_type"], name: "index_pwb_websites_on_site_type"
    t.index ["slug"], name: "index_pwb_websites_on_slug"
    t.index ["subdomain"], name: "index_pwb_websites_on_subdomain", unique: true
    t.check_constraint "rendering_mode::text = ANY (ARRAY['rails'::character varying::text, 'client'::character varying::text])", name: "rendering_mode_valid"
  end

  create_table "pwb_widget_configs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "allowed_domains", default: [], array: true
    t.integer "clicks_count", default: 0
    t.integer "columns", default: 3
    t.datetime "created_at", null: false
    t.boolean "highlighted_only", default: false
    t.integer "impressions_count", default: 0
    t.string "layout", default: "grid"
    t.string "listing_type"
    t.integer "max_bedrooms"
    t.integer "max_price_cents"
    t.integer "max_properties", default: 12
    t.integer "min_bedrooms"
    t.integer "min_price_cents"
    t.string "name", null: false
    t.string "property_types", default: [], array: true
    t.boolean "show_filters", default: false
    t.boolean "show_pagination", default: true
    t.boolean "show_search", default: false
    t.jsonb "theme", default: {}
    t.datetime "updated_at", null: false
    t.jsonb "visible_fields", default: {}
    t.bigint "website_id", null: false
    t.string "widget_key", null: false
    t.index ["website_id", "active"], name: "index_pwb_widget_configs_on_website_id_and_active"
    t.index ["website_id"], name: "index_pwb_widget_configs_on_website_id"
    t.index ["widget_key"], name: "index_pwb_widget_configs_on_widget_key", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "translations", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "interpolations"
    t.boolean "is_proc", default: false
    t.string "key"
    t.string "locale"
    t.string "tag"
    t.datetime "updated_at", precision: nil, null: false
    t.text "value"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ahoy_events", "ahoy_visits", column: "visit_id"
  add_foreign_key "ahoy_events", "pwb_websites", column: "website_id"
  add_foreign_key "ahoy_visits", "pwb_users", column: "user_id"
  add_foreign_key "ahoy_visits", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_ai_generation_requests", "pwb_props", column: "prop_id"
  add_foreign_key "pwb_ai_generation_requests", "pwb_users", column: "user_id"
  add_foreign_key "pwb_ai_generation_requests", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_ai_writing_rules", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_auth_audit_logs", "pwb_users", column: "user_id"
  add_foreign_key "pwb_auth_audit_logs", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_contacts", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_email_templates", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_features", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_field_keys", "pwb_websites"
  add_foreign_key "pwb_market_reports", "pwb_ai_generation_requests", column: "ai_generation_request_id"
  add_foreign_key "pwb_market_reports", "pwb_realty_assets", column: "subject_property_id"
  add_foreign_key "pwb_market_reports", "pwb_users", column: "user_id"
  add_foreign_key "pwb_market_reports", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_media", "pwb_media_folders", column: "folder_id"
  add_foreign_key "pwb_media", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_media_folders", "pwb_media_folders", column: "parent_id"
  add_foreign_key "pwb_media_folders", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_messages", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_page_contents", "pwb_page_contents", column: "parent_page_content_id"
  add_foreign_key "pwb_price_guesses", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_prop_photos", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_prop_translations", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_rental_listings", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_sale_listings", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_saved_properties", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_saved_searches", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_scraped_properties", "pwb_realty_assets", column: "realty_asset_id"
  add_foreign_key "pwb_scraped_properties", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_search_alerts", "pwb_saved_searches", column: "saved_search_id"
  add_foreign_key "pwb_search_filter_options", "pwb_search_filter_options", column: "parent_id"
  add_foreign_key "pwb_search_filter_options", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_shard_audit_logs", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_social_media_posts", "pwb_ai_generation_requests", column: "ai_generation_request_id"
  add_foreign_key "pwb_social_media_posts", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_social_media_templates", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_subdomains", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_subscription_events", "pwb_subscriptions", column: "subscription_id"
  add_foreign_key "pwb_subscriptions", "pwb_plans", column: "plan_id"
  add_foreign_key "pwb_subscriptions", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_support_tickets", "pwb_users", column: "assigned_to_id"
  add_foreign_key "pwb_support_tickets", "pwb_users", column: "creator_id"
  add_foreign_key "pwb_support_tickets", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_testimonials", "pwb_media", column: "author_photo_id"
  add_foreign_key "pwb_testimonials", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_ticket_messages", "pwb_support_tickets", column: "support_ticket_id"
  add_foreign_key "pwb_ticket_messages", "pwb_users", column: "user_id"
  add_foreign_key "pwb_ticket_messages", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_user_memberships", "pwb_users", column: "user_id"
  add_foreign_key "pwb_user_memberships", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_website_integrations", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_website_photos", "pwb_websites", column: "website_id"
  add_foreign_key "pwb_widget_configs", "pwb_websites", column: "website_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade

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
