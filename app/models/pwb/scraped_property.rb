# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_scraped_properties
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  connector_used        :string
#  extracted_data        :jsonb
#  extracted_images      :jsonb
#  extraction_source     :string
#  import_status         :string           default("pending")
#  imported_at           :datetime
#  raw_html              :text
#  scrape_error_message  :string
#  scrape_method         :string
#  scrape_successful     :boolean          default(FALSE)
#  script_json           :text
#  source_host           :string
#  source_portal         :string
#  source_url            :string           not null
#  source_url_normalized :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  realty_asset_id       :uuid
#  website_id            :bigint           not null
#
# Indexes
#
#  index_pwb_scraped_properties_on_import_status               (import_status)
#  index_pwb_scraped_properties_on_realty_asset_id             (realty_asset_id)
#  index_pwb_scraped_properties_on_source_url_normalized       (source_url_normalized)
#  index_pwb_scraped_properties_on_website_id                  (website_id)
#  index_pwb_scraped_properties_on_website_id_and_source_host  (website_id,source_host)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class ScrapedProperty < ApplicationRecord
    self.table_name = "pwb_scraped_properties"

    belongs_to :website, class_name: "Pwb::Website"
    belongs_to :realty_asset, class_name: "Pwb::RealtyAsset", optional: true

    validates :source_url, presence: true
    validates :website, presence: true

    before_save :normalize_source_url, if: :source_url_changed?
    before_save :detect_source_portal, if: :source_url_changed?

    scope :pending, -> { where(import_status: "pending") }
    scope :previewing, -> { where(import_status: "previewing") }
    scope :imported, -> { where(import_status: "imported") }
    scope :successful, -> { where(scrape_successful: true) }
    scope :failed, -> { where(scrape_successful: false) }

    IMPORT_STATUSES = %w[pending previewing imported failed].freeze
    SCRAPE_METHODS = %w[auto manual_html].freeze
    CONNECTORS = %w[http playwright].freeze
    EXTRACTION_SOURCES = %w[external local manual].freeze

    # Known property portals with specific parsing requirements
    KNOWN_PORTALS = {
      "rightmove.co.uk" => "rightmove",
      "zoopla.co.uk" => "zoopla",
      "idealista.com" => "idealista",
      "onthemarket.com" => "onthemarket",
      "zillow.com" => "zillow",
      "redfin.com" => "redfin",
      "realtor.com" => "realtor",
      "trulia.com" => "trulia",
      "daft.ie" => "daft",
      "domain.com.au" => "domain"
    }.freeze

    def asset_data
      extracted_data&.dig("asset_data") || {}
    end

    def listing_data
      extracted_data&.dig("listing_data") || {}
    end

    def images
      extracted_images || []
    end

    def can_preview?
      scrape_successful? && extracted_data.present?
    end

    def already_imported?
      import_status == "imported" && realty_asset.present?
    end

    def mark_as_previewing!
      update!(import_status: "previewing")
    end

    def mark_as_imported!(asset)
      update!(
        import_status: "imported",
        imported_at: Time.current,
        realty_asset: asset
      )
    end

    def mark_as_failed!(error_message)
      update!(
        import_status: "failed",
        scrape_error_message: error_message
      )
    end

    # Class method to find duplicate scraped properties for a URL
    # @param url [String] The URL to check
    # @param website [Pwb::Website] The website context
    # @return [ScrapedProperty, nil] Existing scraped property if found
    def self.find_duplicate(url, website:)
      normalized = normalize_url_string(url)
      where(website: website, source_url_normalized: normalized).first
    end

    # Check if a URL has already been scraped
    # @param url [String] The URL to check
    # @param website [Pwb::Website] The website context
    # @return [Boolean]
    def self.url_already_scraped?(url, website:)
      find_duplicate(url, website: website).present?
    end

    # Check if a URL has been imported (not just scraped)
    # @param url [String] The URL to check
    # @param website [Pwb::Website] The website context
    # @return [Boolean]
    def self.url_already_imported?(url, website:)
      existing = find_duplicate(url, website: website)
      existing&.already_imported? || false
    end

    # Normalize a URL string for comparison (class method version)
    def self.normalize_url_string(url_string)
      uri = URI.parse(url_string.strip)
      "#{uri.host}#{uri.path}".downcase.gsub(%r{/$}, "")
    rescue URI::InvalidURIError
      url_string.downcase.strip
    end

    private

    def normalize_source_url
      return if source_url.blank?

      begin
        uri = URI.parse(source_url.strip)
        self.source_url_normalized = "#{uri.host}#{uri.path}".downcase.gsub(%r{/$}, "")
        self.source_host = uri.host&.downcase
      rescue URI::InvalidURIError
        self.source_url_normalized = source_url.downcase.strip
      end
    end

    def detect_source_portal
      return if source_host.blank?

      KNOWN_PORTALS.each do |domain_pattern, portal_name|
        if source_host.include?(domain_pattern.split(".").first)
          self.source_portal = portal_name
          return
        end
      end

      self.source_portal = "generic"
    end
  end
end
