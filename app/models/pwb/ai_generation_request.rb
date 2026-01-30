# frozen_string_literal: true

module Pwb
  # Records AI content generation requests for tracking, analytics, and cost management.
  #
  # Each request captures:
  # - The type of content generated (listing_description, social_post, etc.)
  # - Input data (property attributes, context)
  # - Output data (generated content)
  # - Token usage for cost tracking
  # - Status for workflow management
  #
  # Multi-tenant: Scoped by website_id
# == Schema Information
#
# Table name: pwb_ai_generation_requests
# Database name: primary
#
#  id            :bigint           not null, primary key
#  ai_model      :string
#  ai_provider   :string           default("anthropic")
#  cost_cents    :integer
#  error_message :text
#  input_data    :jsonb
#  input_tokens  :integer
#  locale        :string           default("en")
#  output_data   :jsonb
#  output_tokens :integer
#  request_type  :string           not null
#  status        :string           default("pending")
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  prop_id       :bigint
#  user_id       :bigint
#  website_id    :bigint           not null
#
# Indexes
#
#  idx_on_website_id_request_type_fcf3872c0b                     (website_id,request_type)
#  index_pwb_ai_generation_requests_on_prop_id                   (prop_id)
#  index_pwb_ai_generation_requests_on_prop_id_and_request_type  (prop_id,request_type)
#  index_pwb_ai_generation_requests_on_user_id                   (user_id)
#  index_pwb_ai_generation_requests_on_website_id                (website_id)
#  index_pwb_ai_generation_requests_on_website_id_and_status     (website_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (prop_id => pwb_props.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
  #
  class AiGenerationRequest < ApplicationRecord
    self.table_name = "pwb_ai_generation_requests"

    # Associations
    belongs_to :website
    belongs_to :user, class_name: "Pwb::User", optional: true
    belongs_to :prop, optional: true

    # Request types
    REQUEST_TYPES = %w[
      listing_description
      social_post
      meta_description
      email_content
      market_report
    ].freeze

    # Status values
    STATUSES = %w[pending processing completed failed].freeze

    # Validations
    validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
    validates :status, inclusion: { in: STATUSES }
    validates :ai_provider, presence: true

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: "completed") }
    scope :failed, -> { where(status: "failed") }
    scope :for_property, ->(prop) { where(prop_id: prop.id) }
    scope :by_type, ->(type) { where(request_type: type) }

    # State transitions
    def mark_processing!
      update!(status: "processing")
    end

    def mark_completed!(output:, input_tokens: nil, output_tokens: nil, cost_cents: nil)
      update!(
        status: "completed",
        output_data: output,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cost_cents: cost_cents
      )
    end

    def mark_failed!(error_message)
      update!(status: "failed", error_message: error_message)
    end

    # Instance methods
    def total_tokens
      (input_tokens || 0) + (output_tokens || 0)
    end

    def processing?
      status == "processing"
    end

    def completed?
      status == "completed"
    end

    def failed?
      status == "failed"
    end

    # Output accessors for common fields
    def generated_title
      output_data&.dig("title")
    end

    def generated_description
      output_data&.dig("description")
    end

    def generated_meta_description
      output_data&.dig("meta_description")
    end

    def compliance_result
      output_data&.dig("compliance")
    end
  end
end
