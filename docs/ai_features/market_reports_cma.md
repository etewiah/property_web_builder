# Market Reports & Comparative Market Analysis (CMA)

## Overview

Generate professional market reports and Comparative Market Analyses (CMAs) that help agents win listings and demonstrate market expertise. Reports combine local market data, property comparisons, and AI-generated insights into polished PDF documents.

## Value Proposition

- **Win More Listings**: Show up to presentations with professional, data-driven CMAs
- **Establish Expertise**: Position agents as local market experts with market reports
- **Lead Generation**: Use reports as lead magnets with built-in contact capture
- **Time Savings**: Generate comprehensive reports in minutes, not hours
- **Brand Consistency**: Customizable templates with agent/brokerage branding

## Report Types

### 1. Comparative Market Analysis (CMA)
For listing presentations - compares a subject property to recent sales and active listings.

### 2. Market Report
For lead generation - neighborhood/area market trends and statistics.

### 3. Buyer Tour Report
For buyer clients - compiled property sheets for showing tours.

### 4. Seller Net Sheet
For listing presentations - estimated seller proceeds calculation.

## Data Model

### Database Schema

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_market_reports.rb
class CreateMarketReports < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_market_reports do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :user, foreign_key: { to_table: :pwb_users }
      t.references :ai_generation_request, foreign_key: { to_table: :pwb_ai_generation_requests }

      # Report type and identification
      t.string :report_type, null: false  # cma, market_report, buyer_tour, seller_net
      t.string :title, null: false
      t.string :reference_number

      # Geographic scope
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :neighborhood
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.decimal :radius_km, precision: 5, scale: 2

      # Subject property (for CMAs)
      t.references :subject_property, foreign_key: { to_table: :pwb_realty_assets }
      t.jsonb :subject_details, default: {}  # For properties not in system

      # Report data
      t.jsonb :comparable_properties, default: []   # Array of property data
      t.jsonb :market_statistics, default: {}       # Aggregated stats
      t.jsonb :ai_insights, default: {}             # AI-generated analysis
      t.jsonb :custom_sections, default: []         # User-added sections

      # Pricing (for CMAs)
      t.integer :suggested_price_low_cents
      t.integer :suggested_price_high_cents
      t.string :suggested_price_currency, default: 'USD'

      # Output
      t.string :pdf_url
      t.string :share_token  # For public sharing

      # Branding
      t.jsonb :branding, default: {}  # Agent photo, logo, contact info

      # Status
      t.string :status, default: 'draft'  # draft, generating, completed, shared
      t.datetime :generated_at
      t.datetime :shared_at
      t.integer :view_count, default: 0

      t.timestamps
    end

    add_index :pwb_market_reports, [:website_id, :report_type]
    add_index :pwb_market_reports, :share_token, unique: true
    add_index :pwb_market_reports, [:city, :region]
    add_index :pwb_market_reports, :status
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_report_templates.rb
class CreateReportTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_report_templates do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      t.string :name, null: false
      t.string :report_type, null: false
      t.text :description

      # Template configuration
      t.jsonb :sections, default: []          # Ordered list of section configs
      t.jsonb :styling, default: {}           # Colors, fonts, etc.
      t.jsonb :default_branding, default: {}  # Default agent/company info

      t.boolean :active, default: true
      t.boolean :is_default, default: false

      t.timestamps
    end

    add_index :pwb_report_templates, [:website_id, :report_type]
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_market_data_snapshots.rb
class CreateMarketDataSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_market_data_snapshots do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # Geographic scope
      t.string :city, null: false
      t.string :region
      t.string :postal_code
      t.string :property_type  # null = all types

      # Time period
      t.date :period_start, null: false
      t.date :period_end, null: false

      # Statistics
      t.integer :total_listings
      t.integer :total_sales
      t.integer :new_listings

      t.integer :median_price_cents
      t.integer :average_price_cents
      t.string :price_currency, default: 'USD'

      t.integer :median_days_on_market
      t.integer :average_days_on_market

      t.decimal :price_per_sqft, precision: 10, scale: 2
      t.decimal :list_to_sale_ratio, precision: 5, scale: 4  # e.g., 0.98 = 98%

      # Inventory
      t.decimal :months_of_inventory, precision: 4, scale: 2

      # Trends (vs previous period)
      t.decimal :price_change_pct, precision: 5, scale: 2
      t.decimal :sales_change_pct, precision: 5, scale: 2
      t.decimal :inventory_change_pct, precision: 5, scale: 2

      t.timestamps
    end

    add_index :pwb_market_data_snapshots, [:website_id, :city, :period_end]
    add_index :pwb_market_data_snapshots, [:city, :region, :property_type, :period_end],
              name: 'idx_market_snapshots_location_period'
  end
end
```

### Model Definitions

```ruby
# app/models/pwb/market_report.rb
module Pwb
  class MarketReport < ApplicationRecord
    belongs_to :website
    belongs_to :user, optional: true
    belongs_to :ai_generation_request, optional: true
    belongs_to :subject_property, class_name: 'Pwb::RealtyAsset', optional: true

    has_one_attached :pdf_file

    enum :report_type, {
      cma: 'cma',
      market_report: 'market_report',
      buyer_tour: 'buyer_tour',
      seller_net: 'seller_net'
    }

    enum :status, {
      draft: 'draft',
      generating: 'generating',
      completed: 'completed',
      shared: 'shared'
    }

    validates :report_type, :title, presence: true
    validates :share_token, uniqueness: true, allow_nil: true

    before_create :generate_reference_number
    before_create :generate_share_token

    scope :recent, -> { order(created_at: :desc) }
    scope :shared, -> { where.not(shared_at: nil) }

    # Money gem integration for suggested price
    monetize :suggested_price_low_cents, with_currency: :suggested_price_currency, allow_nil: true
    monetize :suggested_price_high_cents, with_currency: :suggested_price_currency, allow_nil: true

    def suggested_price_range
      return nil unless suggested_price_low_cents && suggested_price_high_cents

      "#{suggested_price_low.format} - #{suggested_price_high.format}"
    end

    def public_url
      return nil unless share_token

      Rails.application.routes.url_helpers.public_report_url(
        share_token: share_token,
        host: website.primary_host
      )
    end

    def pdf_url
      return nil unless pdf_file.attached?

      Rails.application.routes.url_helpers.rails_blob_url(pdf_file)
    end

    private

    def generate_reference_number
      self.reference_number ||= "#{report_type.upcase[0..2]}-#{SecureRandom.alphanumeric(8).upcase}"
    end

    def generate_share_token
      self.share_token ||= SecureRandom.urlsafe_base64(16)
    end
  end
end
```

```ruby
# app/models/pwb/market_data_snapshot.rb
module Pwb
  class MarketDataSnapshot < ApplicationRecord
    belongs_to :website

    monetize :median_price_cents, with_currency: :price_currency, allow_nil: true
    monetize :average_price_cents, with_currency: :price_currency, allow_nil: true

    validates :city, :period_start, :period_end, presence: true
    validates :period_end, comparison: { greater_than: :period_start }

    scope :for_location, ->(city:, region: nil) {
      scope = where(city: city)
      scope = scope.where(region: region) if region
      scope
    }

    scope :latest, -> { order(period_end: :desc).limit(1) }
    scope :last_year, -> { where('period_end >= ?', 1.year.ago) }

    # Calculate market conditions
    def market_condition
      return :unknown unless months_of_inventory

      case months_of_inventory
      when 0..3 then :sellers_market
      when 3..6 then :balanced
      else :buyers_market
      end
    end

    def market_condition_label
      {
        sellers_market: "Seller's Market",
        balanced: "Balanced Market",
        buyers_market: "Buyer's Market",
        unknown: "Unknown"
      }[market_condition]
    end
  end
end
```

## Service Layer

### CMA Generator

```ruby
# app/services/reports/cma_generator.rb
module Reports
  class CmaGenerator
    attr_reader :website, :subject_property, :options

    def initialize(website:, subject_property: nil, subject_details: {}, options: {})
      @website = website
      @subject_property = subject_property
      @subject_details = subject_details
      @options = options.with_defaults(
        radius_km: 2,
        months_back: 6,
        max_comparables: 10,
        include_active: true,
        include_sold: true
      )
    end

    def generate
      report = create_report

      begin
        report.generating!

        # 1. Find comparable properties
        comparables = find_comparables

        # 2. Calculate market statistics
        statistics = calculate_statistics(comparables)

        # 3. Generate AI insights
        ai_insights = generate_ai_insights(comparables, statistics)

        # 4. Calculate suggested price range
        price_range = calculate_price_range(comparables, statistics)

        # 5. Update report with data
        report.update!(
          comparable_properties: serialize_comparables(comparables),
          market_statistics: statistics,
          ai_insights: ai_insights,
          suggested_price_low_cents: price_range[:low],
          suggested_price_high_cents: price_range[:high],
          suggested_price_currency: price_range[:currency],
          status: :completed,
          generated_at: Time.current
        )

        # 6. Generate PDF (async)
        GenerateReportPdfJob.perform_later(report.id)

        report
      rescue StandardError => e
        report.update!(status: :draft)
        raise
      end
    end

    private

    def create_report
      Pwb::MarketReport.create!(
        website: website,
        user: options[:user],
        report_type: :cma,
        title: build_title,
        subject_property: subject_property,
        subject_details: @subject_details.presence || serialize_subject,
        city: subject_location[:city],
        region: subject_location[:region],
        postal_code: subject_location[:postal_code],
        latitude: subject_location[:latitude],
        longitude: subject_location[:longitude],
        radius_km: options[:radius_km],
        branding: options[:branding] || default_branding
      )
    end

    def build_title
      address = subject_property&.street_address || @subject_details[:address]
      "CMA for #{address || subject_location[:city]}"
    end

    def subject_location
      @subject_location ||= if subject_property
        {
          city: subject_property.city,
          region: subject_property.region,
          postal_code: subject_property.postal_code,
          latitude: subject_property.latitude,
          longitude: subject_property.longitude
        }
      else
        @subject_details.slice(:city, :region, :postal_code, :latitude, :longitude)
      end
    end

    def serialize_subject
      return {} unless subject_property

      {
        address: subject_property.street_address,
        city: subject_property.city,
        region: subject_property.region,
        property_type: subject_property.prop_type_key,
        bedrooms: subject_property.count_bedrooms,
        bathrooms: subject_property.count_bathrooms,
        constructed_area: subject_property.constructed_area,
        plot_area: subject_property.plot_area,
        year_built: subject_property.year_construction,
        features: subject_property.features.pluck(:feature_key)
      }
    end

    def find_comparables
      ComparablesFinder.new(
        subject: subject_property || OpenStruct.new(@subject_details),
        website: website,
        options: options
      ).find
    end

    def calculate_statistics(comparables)
      StatisticsCalculator.new(comparables).calculate
    end

    def generate_ai_insights(comparables, statistics)
      AiInsightsGenerator.new(
        subject: serialize_subject.presence || @subject_details,
        comparables: comparables,
        statistics: statistics,
        website: website
      ).generate
    end

    def calculate_price_range(comparables, statistics)
      PriceRangeCalculator.new(
        subject: subject_property || OpenStruct.new(@subject_details),
        comparables: comparables,
        statistics: statistics
      ).calculate
    end

    def serialize_comparables(comparables)
      comparables.map do |comp|
        {
          id: comp[:id],
          address: comp[:address],
          city: comp[:city],
          property_type: comp[:property_type],
          bedrooms: comp[:bedrooms],
          bathrooms: comp[:bathrooms],
          constructed_area: comp[:constructed_area],
          price: comp[:price],
          price_per_sqft: comp[:price_per_sqft],
          status: comp[:status],  # active, sold, pending
          days_on_market: comp[:days_on_market],
          sold_date: comp[:sold_date],
          distance_km: comp[:distance_km],
          similarity_score: comp[:similarity_score],
          adjustments: comp[:adjustments],
          adjusted_price: comp[:adjusted_price],
          photo_url: comp[:photo_url]
        }
      end
    end

    def default_branding
      agency = website.agency
      {
        agent_name: options.dig(:user, :name),
        agent_photo: options.dig(:user, :avatar_url),
        agent_phone: options.dig(:user, :phone),
        agent_email: options.dig(:user, :email),
        company_name: agency&.company_name,
        company_logo: agency&.logo_url,
        company_phone: agency&.telephone
      }.compact
    end
  end
end
```

### Comparables Finder

```ruby
# app/services/reports/comparables_finder.rb
module Reports
  class ComparablesFinder
    attr_reader :subject, :website, :options

    # Adjustment factors (cents per unit of difference)
    ADJUSTMENTS = {
      bedroom: 15_000_00,      # $15,000 per bedroom
      bathroom: 10_000_00,     # $10,000 per bathroom
      sqft: 150_00,            # $150 per sqft
      year_built: 1_000_00,    # $1,000 per year
      garage: 5_000_00,        # $5,000 per garage
      pool: 25_000_00,         # $25,000 for pool
      lot_size_sqft: 5_00      # $5 per lot sqft
    }.freeze

    def initialize(subject:, website:, options: {})
      @subject = subject
      @website = website
      @options = options
    end

    def find
      # Start with properties in the area
      base_scope = build_base_scope

      # Score and rank by similarity
      scored = score_properties(base_scope)

      # Take top comparables
      top_comparables = scored.sort_by { |p| -p[:similarity_score] }
                              .first(options[:max_comparables] || 10)

      # Calculate adjustments
      top_comparables.map { |comp| calculate_adjustments(comp) }
    end

    private

    def build_base_scope
      scope = Pwb::ListedProperty.where(website_id: website.id)

      # Geographic filter
      if subject.latitude && subject.longitude
        scope = scope.near(
          [subject.latitude, subject.longitude],
          options[:radius_km] || 2,
          units: :km
        )
      else
        scope = scope.where(city: subject.city)
      end

      # Property type filter
      scope = scope.where(prop_type_key: subject.prop_type_key) if subject.prop_type_key

      # Time filter for sold properties
      if options[:include_sold]
        scope = scope.where('sold_at >= ? OR for_sale = ?', options[:months_back].months.ago, true)
      end

      # Bedroom range (+/- 1)
      if subject.count_bedrooms
        scope = scope.where(count_bedrooms: (subject.count_bedrooms - 1)..(subject.count_bedrooms + 1))
      end

      # Size range (+/- 25%)
      if subject.constructed_area
        min_size = subject.constructed_area * 0.75
        max_size = subject.constructed_area * 1.25
        scope = scope.where(constructed_area: min_size..max_size)
      end

      scope
    end

    def score_properties(scope)
      scope.map do |property|
        {
          id: property.id,
          address: property.street_address,
          city: property.city,
          property_type: property.prop_type_key,
          bedrooms: property.count_bedrooms,
          bathrooms: property.count_bathrooms,
          constructed_area: property.constructed_area,
          plot_area: property.plot_area,
          year_built: property.year_construction,
          price: property.current_price_cents,
          price_currency: property.current_price_currency,
          price_per_sqft: calculate_price_per_sqft(property),
          status: determine_status(property),
          days_on_market: property.days_on_market,
          sold_date: property.sold_at,
          distance_km: calculate_distance(property),
          similarity_score: calculate_similarity(property),
          photo_url: property.primary_photo_url,
          features: property.feature_keys
        }
      end
    end

    def calculate_similarity(property)
      score = 100.0

      # Bedroom difference (-10 per bedroom)
      bedroom_diff = (property.count_bedrooms.to_i - subject.count_bedrooms.to_i).abs
      score -= bedroom_diff * 10

      # Bathroom difference (-5 per bathroom)
      bathroom_diff = (property.count_bathrooms.to_f - subject.count_bathrooms.to_f).abs
      score -= bathroom_diff * 5

      # Size difference (-1 per 5% difference)
      if subject.constructed_area && property.constructed_area
        size_pct_diff = ((property.constructed_area - subject.constructed_area) / subject.constructed_area).abs * 100
        score -= size_pct_diff / 5
      end

      # Age difference (-1 per 5 years)
      if subject.year_construction && property.year_construction
        age_diff = (property.year_construction - subject.year_construction).abs
        score -= age_diff / 5
      end

      # Distance penalty (-5 per km)
      distance = calculate_distance(property)
      score -= distance * 5 if distance

      # Recent sale bonus (+10 if sold in last 3 months)
      if property.sold_at && property.sold_at > 3.months.ago
        score += 10
      end

      [score, 0].max
    end

    def calculate_adjustments(comparable)
      adjustments = []
      total_adjustment = 0

      # Bedroom adjustment
      if subject.count_bedrooms && comparable[:bedrooms]
        diff = subject.count_bedrooms - comparable[:bedrooms]
        if diff != 0
          amount = diff * ADJUSTMENTS[:bedroom]
          adjustments << { factor: 'Bedrooms', diff: diff, amount: amount }
          total_adjustment += amount
        end
      end

      # Bathroom adjustment
      if subject.count_bathrooms && comparable[:bathrooms]
        diff = subject.count_bathrooms - comparable[:bathrooms]
        if diff != 0
          amount = (diff * ADJUSTMENTS[:bathroom]).to_i
          adjustments << { factor: 'Bathrooms', diff: diff.round(1), amount: amount }
          total_adjustment += amount
        end
      end

      # Size adjustment
      if subject.constructed_area && comparable[:constructed_area]
        diff = subject.constructed_area - comparable[:constructed_area]
        if diff.abs > 50  # Only adjust if difference > 50 sqft
          amount = (diff * ADJUSTMENTS[:sqft]).to_i
          adjustments << { factor: 'Size (sqft)', diff: diff.round(0), amount: amount }
          total_adjustment += amount
        end
      end

      # Age adjustment
      if subject.year_construction && comparable[:year_built]
        diff = subject.year_construction - comparable[:year_built]
        if diff.abs > 5  # Only adjust if difference > 5 years
          amount = diff * ADJUSTMENTS[:year_built]
          adjustments << { factor: 'Year Built', diff: diff, amount: amount }
          total_adjustment += amount
        end
      end

      comparable[:adjustments] = adjustments
      comparable[:total_adjustment] = total_adjustment
      comparable[:adjusted_price] = comparable[:price] + total_adjustment

      comparable
    end

    def calculate_distance(property)
      return nil unless subject.latitude && subject.longitude && property.latitude && property.longitude

      Geocoder::Calculations.distance_between(
        [subject.latitude, subject.longitude],
        [property.latitude, property.longitude],
        units: :km
      ).round(2)
    end

    def calculate_price_per_sqft(property)
      return nil unless property.constructed_area&.positive? && property.current_price_cents

      (property.current_price_cents / property.constructed_area / 100).round(2)
    end

    def determine_status(property)
      if property.sold_at
        :sold
      elsif property.pending
        :pending
      else
        :active
      end
    end
  end
end
```

### AI Insights Generator

```ruby
# app/services/reports/ai_insights_generator.rb
module Reports
  class AiInsightsGenerator
    attr_reader :subject, :comparables, :statistics, :website

    def initialize(subject:, comparables:, statistics:, website:)
      @subject = subject
      @comparables = comparables
      @statistics = statistics
      @website = website
    end

    def generate
      request = create_request

      begin
        request.processing!

        result = provider.generate(
          prompt: build_prompt,
          system_prompt: system_prompt
        )

        insights = parse_response(result[:content])

        request.update!(
          status: :completed,
          output_data: insights,
          input_tokens: result[:usage][:input_tokens],
          output_tokens: result[:usage][:output_tokens],
          cost_cents: result[:usage][:cost_cents]
        )

        insights
      rescue StandardError => e
        request.update!(status: :failed, error_message: e.message)
        default_insights
      end
    end

    private

    def provider
      @provider ||= Ai::AnthropicProvider.new(
        model: 'claude-sonnet-4-20250514',
        options: { max_tokens: 2048 }
      )
    end

    def create_request
      Pwb::AiGenerationRequest.create!(
        website: website,
        request_type: :market_report,
        ai_provider: 'anthropic',
        ai_model: 'claude-sonnet-4-20250514',
        locale: 'en',
        input_data: {
          subject: subject,
          comparables_count: comparables.size,
          statistics: statistics
        }
      )
    end

    def build_prompt
      <<~PROMPT
        Analyze this Comparative Market Analysis data and provide professional insights:

        ## Subject Property
        #{subject.to_yaml}

        ## Market Statistics
        #{statistics.to_yaml}

        ## Comparable Properties Summary
        - Total comparables: #{comparables.size}
        - Sold: #{comparables.count { |c| c[:status] == :sold }}
        - Active: #{comparables.count { |c| c[:status] == :active }}
        - Average adjusted price: #{average_adjusted_price}
        - Price range: #{price_range}

        Provide insights in this JSON format:
        {
          "executive_summary": "2-3 sentence overview for busy clients",
          "market_position": "How does this property compare to the market",
          "pricing_rationale": "Why the suggested price range makes sense",
          "strengths": ["List 3-5 property strengths"],
          "considerations": ["List 2-3 things that might affect value"],
          "market_trends": "Brief analysis of current market conditions",
          "recommendation": "Clear pricing recommendation with reasoning",
          "time_to_sell_estimate": "Estimated days on market at suggested price"
        }
      PROMPT
    end

    def system_prompt
      <<~SYSTEM
        You are an experienced real estate analyst providing CMA insights for listing agents.

        Guidelines:
        - Be factual and data-driven
        - Provide actionable insights
        - Use professional but accessible language
        - Be honest about market conditions
        - Focus on value for the client presentation
        - Don't oversell - credibility is key

        The agent will use these insights in their listing presentation.
      SYSTEM
    end

    def parse_response(content)
      json_match = content.match(/\{[\s\S]*\}/)
      return default_insights unless json_match

      JSON.parse(json_match[0]).symbolize_keys
    rescue JSON::ParserError
      default_insights
    end

    def default_insights
      {
        executive_summary: "Based on #{comparables.size} comparable properties, this analysis provides a data-driven pricing recommendation.",
        market_position: "The subject property aligns with current market offerings in the area.",
        pricing_rationale: "The suggested price range reflects recent sales and current inventory levels.",
        strengths: ['Location', 'Condition', 'Layout'],
        considerations: ['Market conditions', 'Seasonal factors'],
        market_trends: "The local market shows #{statistics[:months_of_inventory].to_f < 4 ? 'strong seller' : 'balanced'} conditions.",
        recommendation: "Price competitively to attract qualified buyers.",
        time_to_sell_estimate: "#{statistics[:median_days_on_market] || 30} days at suggested price"
      }
    end

    def average_adjusted_price
      return 'N/A' if comparables.empty?

      avg = comparables.sum { |c| c[:adjusted_price] || c[:price] } / comparables.size
      Money.new(avg, comparables.first[:price_currency] || 'USD').format
    end

    def price_range
      return 'N/A' if comparables.empty?

      prices = comparables.map { |c| c[:adjusted_price] || c[:price] }
      currency = comparables.first[:price_currency] || 'USD'

      "#{Money.new(prices.min, currency).format} - #{Money.new(prices.max, currency).format}"
    end
  end
end
```

### PDF Generator

```ruby
# app/services/reports/pdf_generator.rb
module Reports
  class PdfGenerator
    attr_reader :report

    def initialize(report)
      @report = report
    end

    def generate
      pdf = build_pdf

      # Attach to report
      report.pdf_file.attach(
        io: StringIO.new(pdf.render),
        filename: "#{report.reference_number}.pdf",
        content_type: 'application/pdf'
      )

      report.update!(pdf_url: report.pdf_file.url)

      report
    end

    private

    def build_pdf
      Prawn::Document.new(page_size: 'LETTER', margin: 50) do |pdf|
        # Cover page
        render_cover_page(pdf)

        # Executive summary
        pdf.start_new_page
        render_executive_summary(pdf)

        # Subject property details
        pdf.start_new_page
        render_subject_property(pdf)

        # Comparable properties
        pdf.start_new_page
        render_comparables(pdf)

        # Market analysis
        pdf.start_new_page
        render_market_analysis(pdf)

        # Pricing recommendation
        pdf.start_new_page
        render_pricing_recommendation(pdf)

        # Footer on all pages
        add_footer(pdf)
      end
    end

    def render_cover_page(pdf)
      # Company logo
      if report.branding['company_logo']
        pdf.image open(report.branding['company_logo']), position: :center, width: 200
      end

      pdf.move_down 50

      # Report title
      pdf.text report.title, size: 28, style: :bold, align: :center
      pdf.text "Comparative Market Analysis", size: 16, align: :center, color: '666666'

      pdf.move_down 30

      # Property address
      if report.subject_details['address']
        pdf.text report.subject_details['address'], size: 18, align: :center
        pdf.text "#{report.city}, #{report.region}", size: 14, align: :center, color: '666666'
      end

      pdf.move_down 50

      # Prepared by section
      pdf.text "Prepared by:", size: 12, color: '666666'
      pdf.text report.branding['agent_name'] || 'Agent', size: 16, style: :bold

      if report.branding['company_name']
        pdf.text report.branding['company_name'], size: 12
      end

      pdf.text report.branding['agent_phone'] || '', size: 12
      pdf.text report.branding['agent_email'] || '', size: 12

      pdf.move_down 30

      # Date
      pdf.text "Prepared: #{report.generated_at&.strftime('%B %d, %Y')}", size: 10, color: '999999'
    end

    def render_executive_summary(pdf)
      pdf.text "Executive Summary", size: 20, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      if report.ai_insights['executive_summary']
        pdf.text report.ai_insights['executive_summary'], size: 12, leading: 4
      end

      pdf.move_down 20

      # Key metrics box
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
        pdf.fill_color 'F5F5F5'
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 80
        pdf.fill_color '000000'

        pdf.move_down 15
        pdf.indent(20) do
          pdf.text "Suggested List Price Range", size: 10, color: '666666'
          pdf.text report.suggested_price_range || 'Analysis in progress', size: 18, style: :bold
        end
      end
    end

    def render_subject_property(pdf)
      pdf.text "Subject Property", size: 20, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      details = report.subject_details

      # Property photo
      if details['photo_url']
        pdf.image open(details['photo_url']), width: 300, position: :center
        pdf.move_down 20
      end

      # Property details table
      data = [
        ['Address', details['address'] || 'N/A'],
        ['Property Type', details['property_type']&.titleize || 'N/A'],
        ['Bedrooms', details['bedrooms'] || 'N/A'],
        ['Bathrooms', details['bathrooms'] || 'N/A'],
        ['Living Area', details['constructed_area'] ? "#{details['constructed_area']} sqft" : 'N/A'],
        ['Lot Size', details['plot_area'] ? "#{details['plot_area']} sqft" : 'N/A'],
        ['Year Built', details['year_built'] || 'N/A']
      ]

      pdf.table(data, width: pdf.bounds.width) do |t|
        t.cells.padding = 8
        t.cells.borders = [:bottom]
        t.cells.border_color = 'DDDDDD'
        t.column(0).font_style = :bold
        t.column(0).width = 150
      end
    end

    def render_comparables(pdf)
      pdf.text "Comparable Properties", size: 20, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      comparables = report.comparable_properties

      comparables.each_with_index do |comp, index|
        if index > 0 && index % 3 == 0
          pdf.start_new_page
        end

        render_comparable_card(pdf, comp, index + 1)
        pdf.move_down 15
      end
    end

    def render_comparable_card(pdf, comp, number)
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: 120) do
        pdf.stroke_bounds

        pdf.indent(10) do
          pdf.move_down 10
          pdf.text "Comparable ##{number}: #{comp['address']}", size: 12, style: :bold
          pdf.text "#{comp['bedrooms']} bed / #{comp['bathrooms']} bath | #{comp['constructed_area']} sqft", size: 10

          pdf.move_down 5
          status_color = { 'sold' => '28A745', 'active' => '007BFF', 'pending' => 'FFC107' }[comp['status'].to_s] || '666666'
          pdf.text comp['status'].to_s.upcase, size: 8, color: status_color

          pdf.move_down 5
          pdf.text "List Price: #{Money.new(comp['price'], comp['price_currency'] || 'USD').format}", size: 11
          pdf.text "Adjusted Price: #{Money.new(comp['adjusted_price'], comp['price_currency'] || 'USD').format}", size: 11, style: :bold

          if comp['adjustments']&.any?
            pdf.move_down 5
            pdf.text "Adjustments: #{comp['adjustments'].map { |a| a['factor'] }.join(', ')}", size: 9, color: '666666'
          end
        end
      end
    end

    def render_market_analysis(pdf)
      pdf.text "Market Analysis", size: 20, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      stats = report.market_statistics

      # Market condition indicator
      condition = case stats['months_of_inventory'].to_f
                  when 0..3 then "Seller's Market"
                  when 3..6 then "Balanced Market"
                  else "Buyer's Market"
                  end

      pdf.text "Current Market: #{condition}", size: 14, style: :bold
      pdf.move_down 10

      # Statistics table
      data = [
        ['Metric', 'Value'],
        ['Median Sale Price', stats['median_price'] || 'N/A'],
        ['Average Days on Market', stats['median_days_on_market'] || 'N/A'],
        ['Months of Inventory', stats['months_of_inventory'] || 'N/A'],
        ['List-to-Sale Ratio', stats['list_to_sale_ratio'] ? "#{(stats['list_to_sale_ratio'] * 100).round(1)}%" : 'N/A']
      ]

      pdf.table(data, width: 300) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = 'EEEEEE'
        t.cells.padding = 8
      end

      pdf.move_down 20

      if report.ai_insights['market_trends']
        pdf.text "Market Trends", size: 14, style: :bold
        pdf.text report.ai_insights['market_trends'], size: 11, leading: 4
      end
    end

    def render_pricing_recommendation(pdf)
      pdf.text "Pricing Recommendation", size: 20, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      # Suggested price prominently displayed
      pdf.fill_color '007BFF'
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 60
      pdf.fill_color 'FFFFFF'

      pdf.move_down 15
      pdf.indent(20) do
        pdf.text "Recommended List Price Range", size: 12
        pdf.text report.suggested_price_range || 'Contact agent', size: 24, style: :bold
      end

      pdf.fill_color '000000'
      pdf.move_down 30

      # Rationale
      if report.ai_insights['pricing_rationale']
        pdf.text "Rationale", size: 14, style: :bold
        pdf.text report.ai_insights['pricing_rationale'], size: 11, leading: 4
        pdf.move_down 15
      end

      # Strengths
      if report.ai_insights['strengths']&.any?
        pdf.text "Property Strengths", size: 14, style: :bold
        report.ai_insights['strengths'].each do |strength|
          pdf.text "• #{strength}", size: 11
        end
        pdf.move_down 15
      end

      # Final recommendation
      if report.ai_insights['recommendation']
        pdf.text "Recommendation", size: 14, style: :bold
        pdf.text report.ai_insights['recommendation'], size: 11, leading: 4
      end
    end

    def add_footer(pdf)
      pdf.repeat(:all, dynamic: true) do
        pdf.bounding_box([0, 20], width: pdf.bounds.width, height: 30) do
          pdf.stroke_horizontal_rule
          pdf.move_down 5
          pdf.text "#{report.branding['company_name']} | #{report.reference_number} | Page #{pdf.page_number}",
                   size: 8, color: '999999', align: :center
        end
      end
    end
  end
end
```

## API Endpoints

```ruby
# config/routes.rb
namespace :api_manage do
  namespace :v1 do
    scope "/:locale" do
      namespace :reports do
        resources :cmas, only: [:index, :create, :show, :destroy] do
          member do
            post :regenerate
            get :pdf
            post :share
          end
        end

        resources :market_reports, only: [:index, :create, :show, :destroy] do
          member do
            get :pdf
            post :share
          end
        end

        # Market data API
        get 'market_data/:city', to: 'market_data#show'
        get 'market_data/:city/trends', to: 'market_data#trends'
      end
    end
  end
end

# Public sharing route (no auth required)
get '/reports/:share_token', to: 'public_reports#show', as: :public_report
```

```ruby
# app/controllers/api_manage/v1/reports/cmas_controller.rb
module ApiManage
  module V1
    module Reports
      class CmasController < BaseController
        before_action :find_report, only: [:show, :destroy, :regenerate, :pdf, :share]

        # GET /api_manage/v1/:locale/reports/cmas
        def index
          reports = current_website.market_reports
                                   .cma
                                   .includes(:subject_property)
                                   .order(created_at: :desc)
                                   .limit(50)

          render json: {
            reports: reports.map { |r| serialize_report(r) }
          }
        end

        # POST /api_manage/v1/:locale/reports/cmas
        def create
          generator = ::Reports::CmaGenerator.new(
            website: current_website,
            subject_property: find_subject_property,
            subject_details: params[:subject_details]&.to_unsafe_h || {},
            options: generation_options
          )

          report = generator.generate

          render json: {
            success: true,
            report: serialize_report(report, full: true)
          }, status: :created
        end

        # GET /api_manage/v1/:locale/reports/cmas/:id
        def show
          render json: {
            report: serialize_report(@report, full: true)
          }
        end

        # DELETE /api_manage/v1/:locale/reports/cmas/:id
        def destroy
          @report.destroy!
          render json: { success: true, message: 'Report deleted' }
        end

        # POST /api_manage/v1/:locale/reports/cmas/:id/regenerate
        def regenerate
          generator = ::Reports::CmaGenerator.new(
            website: current_website,
            subject_property: @report.subject_property,
            subject_details: @report.subject_details,
            options: generation_options
          )

          new_report = generator.generate

          # Archive old report
          @report.update!(status: 'archived')

          render json: {
            success: true,
            report: serialize_report(new_report, full: true)
          }
        end

        # GET /api_manage/v1/:locale/reports/cmas/:id/pdf
        def pdf
          if @report.pdf_file.attached?
            redirect_to @report.pdf_url, allow_other_host: true
          else
            # Generate PDF on demand
            ::Reports::PdfGenerator.new(@report).generate
            redirect_to @report.pdf_url, allow_other_host: true
          end
        end

        # POST /api_manage/v1/:locale/reports/cmas/:id/share
        def share
          @report.update!(
            status: :shared,
            shared_at: Time.current
          )

          render json: {
            success: true,
            share_url: @report.public_url,
            share_token: @report.share_token
          }
        end

        private

        def find_report
          @report = current_website.market_reports.cma.find(params[:id])
        end

        def find_subject_property
          return nil unless params[:property_id]

          Pwb::RealtyAsset.where(website_id: current_website.id)
                         .find(params[:property_id])
        end

        def generation_options
          {
            user: current_user,
            radius_km: params[:radius_km]&.to_f || 2,
            months_back: params[:months_back]&.to_i || 6,
            max_comparables: params[:max_comparables]&.to_i || 10,
            branding: params[:branding]&.to_unsafe_h
          }
        end

        def serialize_report(report, full: false)
          data = {
            id: report.id,
            reference_number: report.reference_number,
            title: report.title,
            status: report.status,
            city: report.city,
            region: report.region,
            suggested_price_range: report.suggested_price_range,
            pdf_url: report.pdf_url,
            share_url: report.shared? ? report.public_url : nil,
            created_at: report.created_at.iso8601,
            generated_at: report.generated_at&.iso8601
          }

          if full
            data.merge!(
              subject_details: report.subject_details,
              comparable_properties: report.comparable_properties,
              market_statistics: report.market_statistics,
              ai_insights: report.ai_insights,
              branding: report.branding
            )
          end

          data
        end
      end
    end
  end
end
```

## Site Admin Integration

### CMA Creation Flow

```erb
<%# app/views/site_admin/reports/cmas/new.html.erb %>
<div class="max-w-4xl mx-auto py-8"
     data-controller="cma-generator">

  <h1 class="text-2xl font-bold mb-6">Create Comparative Market Analysis</h1>

  <div class="bg-white rounded-lg shadow p-6 mb-6">
    <h2 class="text-lg font-medium mb-4">Subject Property</h2>

    <!-- Property selector or manual entry -->
    <div class="mb-4">
      <label class="flex items-center">
        <input type="radio" name="property_source" value="existing"
               data-action="change->cma-generator#togglePropertySource"
               checked class="mr-2">
        Select from my listings
      </label>
      <label class="flex items-center mt-2">
        <input type="radio" name="property_source" value="manual"
               data-action="change->cma-generator#togglePropertySource"
               class="mr-2">
        Enter property details manually
      </label>
    </div>

    <!-- Existing property selector -->
    <div data-cma-generator-target="existingProperty">
      <select data-cma-generator-target="propertySelect" class="input-field">
        <option value="">Select a property...</option>
        <% @properties.each do |property| %>
          <option value="<%= property.id %>">
            <%= property.street_address %> - <%= property.city %>
          </option>
        <% end %>
      </select>
    </div>

    <!-- Manual entry form -->
    <div data-cma-generator-target="manualProperty" class="hidden space-y-4">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Address</label>
          <input type="text" name="address" class="input-field" data-cma-generator-target="address">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">City</label>
          <input type="text" name="city" class="input-field" data-cma-generator-target="city">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Property Type</label>
          <select name="property_type" class="input-field" data-cma-generator-target="propertyType">
            <option value="single_family">Single Family</option>
            <option value="condo">Condo</option>
            <option value="townhouse">Townhouse</option>
            <option value="multi_family">Multi-Family</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Bedrooms</label>
          <input type="number" name="bedrooms" class="input-field" data-cma-generator-target="bedrooms">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Bathrooms</label>
          <input type="number" step="0.5" name="bathrooms" class="input-field" data-cma-generator-target="bathrooms">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Living Area (sqft)</label>
          <input type="number" name="sqft" class="input-field" data-cma-generator-target="sqft">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Year Built</label>
          <input type="number" name="year_built" class="input-field" data-cma-generator-target="yearBuilt">
        </div>
      </div>
    </div>
  </div>

  <!-- Analysis Options -->
  <div class="bg-white rounded-lg shadow p-6 mb-6">
    <h2 class="text-lg font-medium mb-4">Analysis Options</h2>

    <div class="grid grid-cols-3 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700">Search Radius</label>
        <select data-cma-generator-target="radius" class="input-field">
          <option value="1">1 km</option>
          <option value="2" selected>2 km</option>
          <option value="5">5 km</option>
          <option value="10">10 km</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Time Period</label>
        <select data-cma-generator-target="months" class="input-field">
          <option value="3">Last 3 months</option>
          <option value="6" selected>Last 6 months</option>
          <option value="12">Last 12 months</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Max Comparables</label>
        <select data-cma-generator-target="maxComps" class="input-field">
          <option value="5">5 properties</option>
          <option value="10" selected>10 properties</option>
          <option value="15">15 properties</option>
        </select>
      </div>
    </div>
  </div>

  <!-- Generate Button -->
  <div class="flex justify-end space-x-4">
    <a href="<%= site_admin_reports_cmas_path %>" class="btn btn-secondary">Cancel</a>
    <button type="button"
            data-action="click->cma-generator#generate"
            data-cma-generator-target="generateBtn"
            class="btn btn-primary">
      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
      </svg>
      Generate CMA
    </button>
  </div>

  <!-- Loading State -->
  <div data-cma-generator-target="loading" class="hidden fixed inset-0 bg-gray-900 bg-opacity-50 flex items-center justify-center">
    <div class="bg-white rounded-lg p-8 max-w-md text-center">
      <svg class="animate-spin h-12 w-12 text-blue-600 mx-auto mb-4" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
      </svg>
      <h3 class="text-lg font-medium mb-2">Generating Your CMA</h3>
      <p class="text-gray-600">Finding comparables and analyzing market data...</p>
    </div>
  </div>
</div>
```

## PDF Template System

### Configurable Templates

```ruby
# app/services/reports/template_renderer.rb
module Reports
  class TemplateRenderer
    SECTION_TYPES = %w[
      cover_page
      executive_summary
      subject_property
      comparables_grid
      comparables_detail
      market_statistics
      pricing_recommendation
      market_trends_chart
      agent_bio
      disclaimer
    ].freeze

    attr_reader :report, :template

    def initialize(report:, template: nil)
      @report = report
      @template = template || default_template
    end

    def render
      pdf = Prawn::Document.new(
        page_size: template.styling['page_size'] || 'LETTER',
        margin: template.styling['margins'] || 50
      )

      template.sections.each do |section|
        render_section(pdf, section)
      end

      add_page_numbers(pdf) if template.styling['page_numbers']

      pdf
    end

    private

    def render_section(pdf, section_config)
      section_type = section_config['type']
      return unless SECTION_TYPES.include?(section_type)

      # Start new page if configured
      pdf.start_new_page if section_config['new_page']

      # Call the appropriate section renderer
      send("render_#{section_type}", pdf, section_config)
    end

    def default_template
      OpenStruct.new(
        sections: [
          { 'type' => 'cover_page', 'new_page' => false },
          { 'type' => 'executive_summary', 'new_page' => true },
          { 'type' => 'subject_property', 'new_page' => true },
          { 'type' => 'comparables_grid', 'new_page' => true },
          { 'type' => 'pricing_recommendation', 'new_page' => true },
          { 'type' => 'disclaimer', 'new_page' => true }
        ],
        styling: {
          'page_size' => 'LETTER',
          'margins' => 50,
          'page_numbers' => true,
          'primary_color' => '007BFF',
          'font_family' => 'Helvetica'
        }
      )
    end

    # Section renderers...
    def render_cover_page(pdf, config)
      # Implementation
    end

    def render_executive_summary(pdf, config)
      # Implementation
    end

    # ... other section renderers
  end
end
```

## Implementation Phases

### Phase 1: Core CMA (Week 1-2)
- [ ] Create database migrations
- [ ] Build ComparablesFinder service
- [ ] Implement price adjustments
- [ ] Create basic PDF generator
- [ ] Add API endpoints

### Phase 2: AI Integration (Week 3)
- [ ] Build AiInsightsGenerator
- [ ] Integrate with existing AI provider
- [ ] Add executive summary generation
- [ ] Implement pricing rationale

### Phase 3: PDF & Sharing (Week 4)
- [ ] Professional PDF templates
- [ ] Public sharing functionality
- [ ] QR code lead capture
- [ ] Email delivery

### Phase 4: Market Reports (Week 5-6)
- [ ] Market data aggregation
- [ ] Neighborhood reports
- [ ] Trend charts and graphs
- [ ] Scheduled report generation

### Phase 5: Advanced Features (Future)
- [ ] MLS data integration
- [ ] Custom template builder
- [ ] White-label PDF branding
- [ ] Interactive web reports
- [ ] Automated market updates
