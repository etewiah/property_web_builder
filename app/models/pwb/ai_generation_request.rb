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
