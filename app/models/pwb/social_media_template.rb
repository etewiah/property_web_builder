# frozen_string_literal: true

module Pwb
  # Templates for generating social media posts with consistent branding.
  #
  # Templates use Liquid syntax for placeholders (e.g., {{property_type}}, {{price}})
  # that get replaced with actual listing data during generation.
  #
# == Schema Information
#
# Table name: pwb_social_media_templates
# Database name: primary
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE)
#  caption_template  :text             not null
#  category          :string
#  hashtag_template  :text
#  image_preferences :jsonb
#  is_default        :boolean          default(FALSE)
#  name              :string           not null
#  platform          :string           not null
#  post_type         :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  website_id        :bigint           not null
#
# Indexes
#
#  idx_on_website_id_platform_category_c9f0f62b45  (website_id,platform,category)
#  index_pwb_social_media_templates_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
  # Multi-tenant: Scoped by website_id
  class SocialMediaTemplate < ApplicationRecord
    self.table_name = "pwb_social_media_templates"

    # Associations
    belongs_to :website

    # Enums stored as strings
    PLATFORMS = %w[instagram facebook linkedin twitter tiktok].freeze
    POST_TYPES = %w[feed story reel thread article].freeze
    CATEGORIES = %w[just_listed price_drop open_house sold market_update general].freeze

    # Validations
    validates :name, presence: true
    validates :platform, presence: true, inclusion: { in: PLATFORMS }
    validates :post_type, presence: true, inclusion: { in: POST_TYPES }
    validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
    validates :caption_template, presence: true

    # Scopes
    scope :active, -> { where(active: true) }
    scope :for_platform, ->(platform) { where(platform: platform) }
    scope :for_category, ->(category) { where(category: category) }
    scope :default_templates, -> { where(is_default: true) }

    # Render template with listing data
    # Returns a hash with :caption and :hashtags keys
    def render(listing)
      data = build_template_data(listing)
      rendered_caption = Liquid::Template.parse(caption_template).render(data)
      rendered_hashtags = hashtag_template.present? ?
        Liquid::Template.parse(hashtag_template).render(data) : nil

      {
        caption: rendered_caption.strip,
        hashtags: rendered_hashtags&.strip
      }
    rescue Liquid::Error => e
      Rails.logger.error "Template render error: #{e.message}"
      { caption: caption_template, hashtags: hashtag_template }
    end

    private

    def build_template_data(listing)
      asset = listing.respond_to?(:realty_asset) ? listing.realty_asset : listing

      {
        "property_type" => asset.try(:prop_type_key) || "property",
        "bedrooms" => asset.try(:count_bedrooms) || 0,
        "bathrooms" => asset.try(:count_bathrooms) || 0,
        "price" => format_price(listing),
        "city" => asset.try(:city) || "",
        "region" => asset.try(:region) || "",
        "address" => asset.try(:full_address) || "",
        "title" => listing.try(:title) || asset.try(:title) || "",
        "description" => listing.try(:description) || asset.try(:description) || "",
        "url" => listing_url(listing)
      }
    end

    def format_price(listing)
      if listing.respond_to?(:price_sale_current_cents) && listing.price_sale_current_cents
        Money.new(listing.price_sale_current_cents, listing.price_sale_current_currency).format
      elsif listing.respond_to?(:price_rental_monthly_current_cents) && listing.price_rental_monthly_current_cents
        "#{Money.new(listing.price_rental_monthly_current_cents, listing.price_rental_monthly_current_currency).format}/mo"
      else
        "Price on request"
      end
    rescue StandardError
      "Price on request"
    end

    def listing_url(listing)
      asset = listing.respond_to?(:realty_asset) ? listing.realty_asset : listing
      website = asset.try(:website) || listing.try(:website)
      return "" unless website && asset

      "#{website.primary_url}/properties/#{asset.slug}"
    end
  end
end
