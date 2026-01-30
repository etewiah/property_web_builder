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
# == Schema Information
#
# Table name: pwb_ai_writing_rules
# Database name: primary
#
#  id           :bigint           not null, primary key
#  active       :boolean          default(TRUE)
#  description  :text
#  name         :string           not null
#  position     :integer          default(0)
#  rule_content :text             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  website_id   :bigint           not null
#
# Indexes
#
#  index_pwb_ai_writing_rules_on_website_id             (website_id)
#  index_pwb_ai_writing_rules_on_website_id_and_active  (website_id,active)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
