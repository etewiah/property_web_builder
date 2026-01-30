# frozen_string_literal: true

module Pwb
  # Custom writing rules/guidelines for AI content generation per website.
  #
  # Allows agencies to define their brand voice, style preferences,
  # and specific content requirements that the AI should follow.
  #
  # Examples:
  # - "Always mention proximity to public transport"
  # - "Use formal British English spelling"
  # - "Avoid superlatives like 'best' or 'amazing'"
  #
  # Multi-tenant: Scoped by website_id
  #
  class AiWritingRule < ApplicationRecord
    self.table_name = "pwb_ai_writing_rules"

    # Associations
    belongs_to :website

    # Validations
    validates :name, presence: true, length: { maximum: 100 }
    validates :rule_content, presence: true, length: { maximum: 1000 }

    # Scopes
    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(position: :asc, created_at: :asc) }

    # Class methods
    def self.for_prompt(website)
      website.ai_writing_rules.active.ordered.pluck(:rule_content)
    end
  end
end
