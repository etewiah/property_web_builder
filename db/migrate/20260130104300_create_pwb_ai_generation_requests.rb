# frozen_string_literal: true

class CreatePwbAiGenerationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_ai_generation_requests do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :user, foreign_key: { to_table: :users }
      t.references :prop, foreign_key: { to_table: :pwb_props }

      t.string :request_type, null: false  # 'listing_description', 'social_post', etc.
      t.string :ai_provider, default: 'anthropic'
      t.string :ai_model
      t.jsonb :input_data, default: {}
      t.jsonb :output_data, default: {}
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cost_cents
      t.string :status, default: 'pending'  # pending, processing, completed, failed
      t.text :error_message
      t.string :locale, default: 'en'

      t.timestamps
    end

    add_index :pwb_ai_generation_requests, [:website_id, :request_type]
    add_index :pwb_ai_generation_requests, [:website_id, :status]
    add_index :pwb_ai_generation_requests, [:prop_id, :request_type]
  end
end
