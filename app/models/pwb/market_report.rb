# frozen_string_literal: true

module Pwb
  # Records CMA (Comparative Market Analysis) and market reports.
  #
  # Each report captures:
  # - Subject property details
  # - Comparable properties with adjustments
  # - Market statistics
  # - AI-generated insights and pricing recommendations
  #
  # Multi-tenant: Scoped by website_id
  #
  class MarketReport < ApplicationRecord
    self.table_name = "pwb_market_reports"

    # Associations
    belongs_to :website
    belongs_to :user, class_name: "Pwb::User", optional: true
    belongs_to :ai_generation_request, class_name: "Pwb::AiGenerationRequest", optional: true
    belongs_to :subject_property, class_name: "Pwb::RealtyAsset", optional: true

    # Has one attached PDF
    has_one_attached :pdf_file

    # Report types
    REPORT_TYPES = %w[cma market_report].freeze

    # Status values
    STATUSES = %w[draft generating completed shared].freeze

    # Validations
    validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }
    validates :status, inclusion: { in: STATUSES }
    validates :title, presence: true
    validates :share_token, uniqueness: true, allow_nil: true

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: "completed") }
    scope :shared, -> { where(status: "shared") }
    scope :drafts, -> { where(status: "draft") }
    scope :by_type, ->(type) { where(report_type: type) }
    scope :cmas, -> { by_type("cma") }

    # Callbacks
    before_create :generate_reference_number
    before_create :set_default_branding

    # State transitions
    def mark_generating!
      update!(status: "generating")
    end

    def mark_completed!(insights: nil, statistics: nil, comparables: nil, suggested_price: nil)
      attrs = {
        status: "completed",
        generated_at: Time.current
      }
      attrs[:ai_insights] = insights if insights.present?
      attrs[:market_statistics] = statistics if statistics.present?
      attrs[:comparable_properties] = comparables if comparables.present?

      if suggested_price.present?
        attrs[:suggested_price_low_cents] = suggested_price[:low_cents]
        attrs[:suggested_price_high_cents] = suggested_price[:high_cents]
        attrs[:suggested_price_currency] = suggested_price[:currency] || "USD"
      end

      update!(attrs)
    end

    def mark_shared!
      update!(status: "shared", shared_at: Time.current, share_token: generate_share_token)
    end

    # Status helpers
    def draft?
      status == "draft"
    end

    def generating?
      status == "generating"
    end

    def completed?
      status == "completed"
    end

    def shared?
      status == "shared"
    end

    def cma?
      report_type == "cma"
    end

    # Increment view count
    def record_view!
      increment!(:view_count)
    end

    # PDF helpers
    def pdf_ready?
      pdf_file.attached?
    end

    def pdf_filename
      "#{report_type}_#{reference_number}.pdf"
    end

    # Price range helpers
    def suggested_price_range
      return nil unless suggested_price_low_cents && suggested_price_high_cents

      {
        low: suggested_price_low_cents,
        high: suggested_price_high_cents,
        currency: suggested_price_currency,
        formatted_low: format_price(suggested_price_low_cents),
        formatted_high: format_price(suggested_price_high_cents)
      }
    end

    # JSONB accessors
    def executive_summary
      ai_insights&.dig("executive_summary")
    end

    def market_position
      ai_insights&.dig("market_position")
    end

    def pricing_rationale
      ai_insights&.dig("pricing_rationale")
    end

    def strengths
      ai_insights&.dig("strengths") || []
    end

    def considerations
      ai_insights&.dig("considerations") || []
    end

    def recommendation
      ai_insights&.dig("recommendation")
    end

    def time_to_sell_estimate
      ai_insights&.dig("time_to_sell_estimate")
    end

    # Market statistics accessors
    def average_price
      market_statistics&.dig("average_price")
    end

    def median_price
      market_statistics&.dig("median_price")
    end

    def price_per_sqft
      market_statistics&.dig("price_per_sqft")
    end

    def days_on_market
      market_statistics&.dig("days_on_market")
    end

    def comparable_count
      comparable_properties&.length || 0
    end

    # Branding accessors
    def agent_name
      branding&.dig("agent_name")
    end

    def agent_phone
      branding&.dig("agent_phone")
    end

    def agent_email
      branding&.dig("agent_email")
    end

    def company_name
      branding&.dig("company_name") || website&.company_display_name
    end

    def company_logo_url
      branding&.dig("company_logo_url") || website&.main_logo_url
    end

    private

    def generate_reference_number
      self.reference_number ||= "CMA-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(6).upcase}"
    end

    def generate_share_token
      SecureRandom.urlsafe_base64(16)
    end

    def set_default_branding
      return if branding.present?

      self.branding = {
        company_name: website&.company_display_name,
        company_logo_url: website&.main_logo_url
      }.compact
    end

    def format_price(cents)
      return nil unless cents

      currency_symbol = case suggested_price_currency
                        when "USD" then "$"
                        when "EUR" then "€"
                        when "GBP" then "£"
                        else suggested_price_currency
                        end

      "#{currency_symbol}#{(cents / 100.0).round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end
  end
end
