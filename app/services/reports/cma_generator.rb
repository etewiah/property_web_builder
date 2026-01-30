# frozen_string_literal: true

module Reports
  # Orchestrates the full CMA (Comparative Market Analysis) generation workflow.
  #
  # This service coordinates:
  # 1. Creating the market report record
  # 2. Finding comparable properties
  # 3. Calculating market statistics
  # 4. Generating AI insights
  # 5. Enqueuing PDF generation job
  #
  # Usage:
  #   generator = Reports::CmaGenerator.new(
  #     property: realty_asset,
  #     website: website,
  #     user: current_user,
  #     options: { radius_km: 2, generate_pdf: true }
  #   )
  #   result = generator.generate
  #
  #   if result.success?
  #     puts result.report.reference_number
  #   else
  #     puts result.error
  #   end
  #
  class CmaGenerator
    Result = Struct.new(:success, :report, :comparables, :statistics, :insights, :error, keyword_init: true) do
      def success?
        success
      end
    end

    DEFAULT_OPTIONS = {
      radius_km: 2,
      months_back: 6,
      max_comparables: 10,
      generate_pdf: true,
      title: nil,
      branding: {}
    }.freeze

    def initialize(property:, website:, user: nil, options: {})
      @property = property
      @website = website
      @user = user
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def generate
      # Step 1: Create report record
      report = create_report

      begin
        report.mark_generating!

        # Step 2: Find comparable properties
        comparables_result = find_comparables
        comparables = comparables_result.comparables

        if comparables.empty?
          report.update!(status: 'completed', generated_at: Time.current)
          return Result.new(
            success: true,
            report: report,
            comparables: [],
            statistics: nil,
            insights: nil,
            error: "No comparable properties found within search criteria"
          )
        end

        # Step 3: Calculate market statistics
        statistics = calculate_statistics(comparables)

        # Step 4: Generate AI insights
        insights_result = generate_insights(report, comparables, statistics)

        if insights_result.success?
          # Step 5: Update report with all data
          report.mark_completed!(
            insights: insights_result.insights,
            statistics: statistics.statistics,
            comparables: comparables,
            suggested_price: insights_result.suggested_price
          )

          # Update the AI generation request association
          report.update!(ai_generation_request_id: insights_result.request_id)

          # Step 6: Enqueue PDF generation
          enqueue_pdf_generation(report) if @options[:generate_pdf]

          Result.new(
            success: true,
            report: report.reload,
            comparables: comparables,
            statistics: statistics,
            insights: insights_result.insights
          )
        else
          # Mark report as completed without AI insights
          report.mark_completed!(
            statistics: statistics.statistics,
            comparables: comparables
          )

          Result.new(
            success: false,
            report: report.reload,
            comparables: comparables,
            statistics: statistics,
            error: insights_result.error
          )
        end
      rescue ::Ai::ConfigurationError => e
        report.update!(status: 'draft')
        raise
      rescue ::Ai::RateLimitError => e
        report.update!(status: 'draft')
        raise
      rescue StandardError => e
        Rails.logger.error "[CmaGenerator] Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
        report.update!(status: 'draft')
        Result.new(success: false, report: report, error: e.message)
      end
    end

    private

    def create_report
      title = @options[:title] || generate_title
      branding = @options[:branding].presence || default_branding

      Pwb::MarketReport.create!(
        website: @website,
        user: @user,
        subject_property: @property,
        report_type: 'cma',
        title: title,
        status: 'draft',
        city: @property.city,
        region: @property.region,
        postal_code: @property.postal_code,
        latitude: @property.latitude,
        longitude: @property.longitude,
        radius_km: @options[:radius_km],
        subject_details: build_subject_details,
        branding: branding,
        suggested_price_currency: determine_currency
      )
    end

    def find_comparables
      ComparablesFinder.new(
        subject: @property,
        website: @website,
        options: {
          radius_km: @options[:radius_km],
          months_back: @options[:months_back],
          max_comparables: @options[:max_comparables]
        }
      ).find
    end

    def calculate_statistics(comparables)
      StatisticsCalculator.new(
        comparables: comparables,
        subject: @property,
        currency: determine_currency
      ).calculate
    end

    def generate_insights(report, comparables, statistics)
      CmaInsightsGenerator.new(
        report: report,
        comparables: comparables,
        statistics: statistics
      ).generate
    end

    def enqueue_pdf_generation(report)
      if defined?(GenerateReportPdfJob)
        GenerateReportPdfJob.perform_later(
          report_id: report.id,
          website_id: @website.id
        )
      else
        Rails.logger.warn "[CmaGenerator] GenerateReportPdfJob not defined, skipping PDF generation"
      end
    end

    def generate_title
      address = [@property.street_address, @property.city].compact.reject(&:blank?).join(', ')
      address = 'Subject Property' if address.blank?

      "CMA Report for #{address}"
    end

    def build_subject_details
      {
        property_id: @property.id,
        reference: @property.reference,
        address: {
          street: @property.street_address,
          city: @property.city,
          region: @property.region,
          postal_code: @property.postal_code,
          country: @property.country
        },
        characteristics: {
          property_type: @property.prop_type_key,
          bedrooms: @property.count_bedrooms,
          bathrooms: @property.count_bathrooms,
          constructed_area: @property.constructed_area,
          plot_area: @property.plot_area,
          year_built: @property.year_construction,
          garages: @property.count_garages
        },
        coordinates: {
          latitude: @property.latitude,
          longitude: @property.longitude
        }
      }.compact_blank
    end

    def default_branding
      agency = @website.agency

      {
        company_name: agency&.display_name || @website.company_display_name,
        company_logo_url: @website.main_logo_url,
        agent_name: @user&.full_name,
        agent_email: @user&.email,
        agent_phone: agency&.phone_number_primary
      }.compact
    end

    def determine_currency
      # Try to get currency from property listings or website default
      if @property.respond_to?(:sale_listings) && @property.sale_listings.any?
        @property.sale_listings.first.price_current_currency
      elsif @property.respond_to?(:rental_listings) && @property.rental_listings.any?
        @property.rental_listings.first.price_current_currency
      else
        @website.default_currency || 'USD'
      end
    end
  end
end
