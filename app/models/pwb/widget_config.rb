# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_widget_configs
#
#  id                :uuid             not null, primary key
#  active            :boolean          default(TRUE), not null
#  allowed_domains   :string           default([]), is an Array
#  clicks_count      :integer          default(0)
#  columns           :integer          default(3)
#  highlighted_only  :boolean          default(FALSE)
#  impressions_count :integer          default(0)
#  layout            :string           default("grid")
#  listing_type      :string
#  max_bedrooms      :integer
#  max_price_cents   :integer
#  max_properties    :integer          default(12)
#  min_bedrooms      :integer
#  min_price_cents   :integer
#  name              :string           not null
#  property_types    :string           default([]), is an Array
#  show_filters      :boolean          default(FALSE)
#  show_pagination   :boolean          default(TRUE)
#  show_search       :boolean          default(FALSE)
#  theme             :jsonb
#  visible_fields    :jsonb
#  widget_key        :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  website_id        :bigint           not null
#
# Indexes
#
#  index_pwb_widget_configs_on_website_id             (website_id)
#  index_pwb_widget_configs_on_website_id_and_active  (website_id,active)
#  index_pwb_widget_configs_on_widget_key             (widget_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class WidgetConfig < ApplicationRecord
    belongs_to :website, class_name: 'Pwb::Website'

    # Validations
    validates :name, presence: true
    validates :widget_key, presence: true, uniqueness: true
    validates :layout, inclusion: { in: %w[grid list carousel] }
    validates :columns, numericality: { in: 1..6 }
    validates :max_properties, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
    validates :listing_type, inclusion: { in: %w[sale rent] }, allow_nil: true

    # Callbacks
    before_validation :generate_widget_key, on: :create

    # Scopes
    scope :active, -> { where(active: true) }

    # Default theme settings
    DEFAULT_THEME = {
      'primary_color' => '#3B82F6',
      'secondary_color' => '#1E40AF',
      'text_color' => '#1F2937',
      'background_color' => '#FFFFFF',
      'card_background' => '#F9FAFB',
      'border_color' => '#E5E7EB',
      'border_radius' => '8px',
      'font_family' => 'system-ui, -apple-system, sans-serif'
    }.freeze

    # Default visible fields
    DEFAULT_VISIBLE_FIELDS = {
      'price' => true,
      'bedrooms' => true,
      'bathrooms' => true,
      'area' => true,
      'location' => true,
      'reference' => false,
      'property_type' => true
    }.freeze

    # Get theme with defaults merged
    def effective_theme
      DEFAULT_THEME.merge(theme || {})
    end

    # Get visible fields with defaults merged
    def effective_visible_fields
      DEFAULT_VISIBLE_FIELDS.merge(visible_fields || {})
    end

    # Build the properties query based on widget configuration
    def properties_query
      scope = website.listed_properties.visible

      # Filter by listing type
      case listing_type
      when 'sale'
        scope = scope.for_sale
      when 'rent'
        scope = scope.for_rent
      end

      # Filter by highlighted
      scope = scope.highlighted if highlighted_only

      # Filter by property types
      if property_types.present?
        scope = scope.where(prop_type_key: property_types)
      end

      # Filter by price (for sale)
      if listing_type == 'sale' || listing_type.nil?
        scope = scope.where('price_sale_current_cents >= ?', min_price_cents) if min_price_cents.present?
        scope = scope.where('price_sale_current_cents <= ?', max_price_cents) if max_price_cents.present?
      end

      # Filter by price (for rent)
      if listing_type == 'rent'
        scope = scope.where('price_rental_monthly_current_cents >= ?', min_price_cents) if min_price_cents.present?
        scope = scope.where('price_rental_monthly_current_cents <= ?', max_price_cents) if max_price_cents.present?
      end

      # Filter by bedrooms
      scope = scope.where('count_bedrooms >= ?', min_bedrooms) if min_bedrooms.present?
      scope = scope.where('count_bedrooms <= ?', max_bedrooms) if max_bedrooms.present?

      # Order and limit
      scope.order(highlighted: :desc, created_at: :desc).limit(max_properties)
    end

    # Check if a domain is allowed to embed this widget
    def domain_allowed?(domain)
      return true if allowed_domains.blank? # No restrictions
      return false if domain.blank?

      # Normalize domain
      normalized = domain.to_s.downcase.gsub(/^www\./, '')

      allowed_domains.any? do |allowed|
        pattern = allowed.downcase.gsub(/^www\./, '')
        # Support wildcard subdomains (*.example.com)
        if pattern.start_with?('*.')
          normalized.end_with?(pattern[1..]) || normalized == pattern[2..]
        else
          normalized == pattern
        end
      end
    end

    # Generate embed code for this widget
    def embed_code(host: nil)
      widget_host = host || website.primary_host || "#{website.subdomain}.propertywebbuilder.com"

      <<~HTML.strip
        <!-- PropertyWebBuilder Widget -->
        <div id="pwb-widget-#{widget_key}"></div>
        <script src="https://#{widget_host}/widget.js" data-widget-id="#{widget_key}" async></script>
      HTML
    end

    # Generate iframe embed code (alternative)
    def iframe_embed_code(host: nil)
      widget_host = host || website.primary_host || "#{website.subdomain}.propertywebbuilder.com"

      <<~HTML.strip
        <!-- PropertyWebBuilder Widget (iframe) -->
        <iframe
          src="https://#{widget_host}/widget/#{widget_key}"
          width="100%"
          height="600"
          frameborder="0"
          style="border: none; width: 100%; min-height: 600px;"
          loading="lazy"
          title="Property Listings">
        </iframe>
      HTML
    end

    # Increment impression counter (called when widget loads)
    def record_impression!
      increment!(:impressions_count)
    end

    # Increment click counter (called when property is clicked)
    def record_click!
      increment!(:clicks_count)
    end

    # Serialization for API
    def as_widget_config
      {
        widget_key: widget_key,
        layout: layout,
        columns: columns,
        max_properties: max_properties,
        show_search: show_search,
        show_filters: show_filters,
        show_pagination: show_pagination,
        listing_type: listing_type,
        theme: effective_theme,
        visible_fields: effective_visible_fields
      }
    end

    private

    def generate_widget_key
      return if widget_key.present?

      loop do
        self.widget_key = SecureRandom.alphanumeric(12).downcase
        break unless self.class.exists?(widget_key: widget_key)
      end
    end
  end
end
