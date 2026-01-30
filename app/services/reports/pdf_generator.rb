# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

module Reports
  # Generates PDF documents for CMA (Comparative Market Analysis) reports.
  #
  # Creates professional PDF reports with:
  # - Cover page with branding
  # - Executive summary
  # - Subject property details
  # - Comparables grid with adjustments
  # - Market analysis
  # - Pricing recommendation
  #
  # Usage:
  #   generator = Reports::PdfGenerator.new(report)
  #   generator.generate
  #   # PDF is attached to report.pdf_file
  #
  class PdfGenerator
    COLORS = {
      primary: '2563EB',      # Blue
      secondary: '64748B',    # Slate gray
      success: '16A34A',      # Green
      warning: 'D97706',      # Amber
      text: '1E293B',         # Dark slate
      light_text: '64748B',   # Light text
      border: 'E2E8F0',       # Light border
      background: 'F8FAFC'    # Very light background
    }.freeze

    def initialize(report)
      @report = report
      @subject = report.subject_property
      @comparables = report.comparable_properties || []
      @statistics = report.market_statistics || {}
      @insights = report.ai_insights || {}
    end

    def generate
      pdf = Prawn::Document.new(
        page_size: 'A4',
        margin: [50, 50, 50, 50],
        info: pdf_metadata
      )

      render_cover_page(pdf)
      pdf.start_new_page

      render_executive_summary(pdf)
      render_subject_property(pdf)
      render_comparables_table(pdf)

      pdf.start_new_page
      render_market_analysis(pdf)
      render_pricing_recommendation(pdf)
      render_footer(pdf)

      attach_pdf(pdf)
    end

    private

    def pdf_metadata
      {
        Title: @report.title,
        Author: @report.agent_name || @report.company_name,
        Subject: "Comparative Market Analysis",
        Creator: "PropertyWebBuilder CMA Generator",
        CreationDate: Time.current
      }
    end

    def render_cover_page(pdf)
      # Logo (if available)
      if @report.company_logo_url.present?
        begin
          # pdf.image open(@report.company_logo_url), width: 150, position: :center
          # For now, just show company name as we can't easily fetch remote images
          pdf.move_down 30
        rescue StandardError => e
          Rails.logger.warn "[PdfGenerator] Could not load logo: #{e.message}"
        end
      end

      pdf.move_down 100

      # Title
      pdf.font_size 32 do
        pdf.text "Comparative Market Analysis", align: :center, style: :bold, color: COLORS[:primary]
      end

      pdf.move_down 30

      # Property address
      if @subject
        address = [@subject.street_address, @subject.city, @subject.postal_code]
                  .compact.reject(&:blank?).join(', ')
        pdf.font_size 18 do
          pdf.text address, align: :center, color: COLORS[:text]
        end
      end

      pdf.move_down 50

      # Prepared for / by info
      pdf.font_size 12 do
        pdf.text "Prepared by:", align: :center, color: COLORS[:light_text]
        pdf.move_down 5
        pdf.text @report.company_name || 'Real Estate Professional', align: :center, style: :bold, color: COLORS[:text]

        if @report.agent_name
          pdf.move_down 10
          pdf.text @report.agent_name, align: :center, color: COLORS[:text]
        end

        if @report.agent_email || @report.agent_phone
          pdf.move_down 5
          contact = [@report.agent_email, @report.agent_phone].compact.join(' | ')
          pdf.text contact, align: :center, color: COLORS[:light_text]
        end
      end

      pdf.move_down 50

      # Date and reference
      pdf.font_size 10 do
        pdf.text "Report Date: #{@report.generated_at&.strftime('%B %d, %Y') || Date.today.strftime('%B %d, %Y')}", align: :center, color: COLORS[:light_text]
        pdf.text "Reference: #{@report.reference_number}", align: :center, color: COLORS[:light_text]
      end
    end

    def render_executive_summary(pdf)
      section_header(pdf, "Executive Summary")

      if @insights['executive_summary'].present?
        pdf.text @insights['executive_summary'], size: 12, color: COLORS[:text], leading: 4
        pdf.move_down 15
      end

      # Price recommendation box
      if @report.suggested_price_low_cents && @report.suggested_price_high_cents
        pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
          pdf.fill_color COLORS[:background]
          pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 60
          pdf.fill_color '000000'

          pdf.move_down 15
          pdf.font_size 11 do
            pdf.text "Suggested Listing Price Range:", align: :center, color: COLORS[:light_text]
          end
          pdf.move_down 5
          pdf.font_size 20 do
            range = @report.suggested_price_range
            pdf.text "#{range[:formatted_low]} - #{range[:formatted_high]}", align: :center, style: :bold, color: COLORS[:primary]
          end
          pdf.move_down 10
        end
      end

      pdf.move_down 20
    end

    def render_subject_property(pdf)
      section_header(pdf, "Subject Property")

      return unless @subject

      details = [
        ["Address", [@subject.street_address, @subject.city, @subject.postal_code].compact.join(', ')],
        ["Property Type", @subject.prop_type_key&.humanize],
        ["Bedrooms", @subject.count_bedrooms],
        ["Bathrooms", @subject.count_bathrooms],
        ["Size", "#{@subject.constructed_area} sqm"],
        ["Year Built", @subject.year_construction],
        ["Garages", @subject.count_garages]
      ].reject { |_, v| v.blank? || v == 0 }

      table_data = details.map { |label, value| [label, value.to_s] }

      pdf.table(table_data, width: 300) do |table|
        table.cells.padding = [8, 10]
        table.cells.borders = [:bottom]
        table.cells.border_color = COLORS[:border]
        table.column(0).font_style = :bold
        table.column(0).text_color = COLORS[:light_text]
        table.column(1).text_color = COLORS[:text]
      end

      pdf.move_down 25
    end

    def render_comparables_table(pdf)
      section_header(pdf, "Comparable Properties (#{@comparables.length})")

      return if @comparables.empty?

      # Headers
      headers = ['Address', 'Price', 'Beds', 'Baths', 'Size', 'Score', 'Adj. Price']

      # Data rows
      rows = @comparables.map do |comp|
        [
          truncate_text(comp['address'] || comp[:address], 25),
          format_price(comp['price_cents'] || comp[:price_cents]),
          comp['bedrooms'] || comp[:bedrooms],
          comp['bathrooms'] || comp[:bathrooms],
          "#{comp['constructed_area'] || comp[:constructed_area]}",
          "#{comp['similarity_score'] || comp[:similarity_score]}%",
          format_price(comp['adjusted_price_cents'] || comp[:adjusted_price_cents])
        ]
      end

      pdf.table([headers] + rows, width: pdf.bounds.width, header: true) do |table|
        table.cells.padding = [6, 5]
        table.cells.size = 9
        table.cells.borders = [:bottom]
        table.cells.border_color = COLORS[:border]

        table.row(0).font_style = :bold
        table.row(0).background_color = COLORS[:background]
        table.row(0).text_color = COLORS[:light_text]

        table.cells.text_color = COLORS[:text]
      end

      pdf.move_down 25
    end

    def render_market_analysis(pdf)
      section_header(pdf, "Market Analysis")

      # Market position
      if @insights['market_position'].present?
        pdf.text "Market Position", size: 12, style: :bold, color: COLORS[:text]
        pdf.move_down 5
        pdf.text @insights['market_position'], size: 11, color: COLORS[:text], leading: 3
        pdf.move_down 15
      end

      # Statistics
      if @statistics.present?
        pdf.text "Key Statistics", size: 12, style: :bold, color: COLORS[:text]
        pdf.move_down 5

        stats_data = [
          ["Average Price", format_price(@statistics['average_price'])],
          ["Median Price", format_price(@statistics['median_price'])],
          ["Adjusted Average", format_price(@statistics['adjusted_average_price'])],
          ["Price per Sqm", format_price(@statistics['price_per_sqft'])],
          ["Comparable Count", @statistics['comparable_count']]
        ].reject { |_, v| v.nil? }

        pdf.table(stats_data, width: 300) do |table|
          table.cells.padding = [6, 10]
          table.cells.borders = [:bottom]
          table.cells.border_color = COLORS[:border]
          table.column(0).text_color = COLORS[:light_text]
          table.column(1).text_color = COLORS[:text]
          table.column(1).font_style = :bold
        end

        pdf.move_down 15
      end

      # Strengths
      if @insights['strengths'].present? && @insights['strengths'].any?
        pdf.text "Property Strengths", size: 12, style: :bold, color: COLORS[:success]
        pdf.move_down 5
        @insights['strengths'].each do |strength|
          pdf.text "• #{strength}", size: 11, color: COLORS[:text], leading: 3
        end
        pdf.move_down 15
      end

      # Considerations
      if @insights['considerations'].present? && @insights['considerations'].any?
        pdf.text "Considerations", size: 12, style: :bold, color: COLORS[:warning]
        pdf.move_down 5
        @insights['considerations'].each do |consideration|
          pdf.text "• #{consideration}", size: 11, color: COLORS[:text], leading: 3
        end
        pdf.move_down 15
      end
    end

    def render_pricing_recommendation(pdf)
      section_header(pdf, "Pricing Recommendation")

      if @insights['pricing_rationale'].present?
        pdf.text @insights['pricing_rationale'], size: 11, color: COLORS[:text], leading: 3
        pdf.move_down 15
      end

      if @insights['recommendation'].present?
        pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
          pdf.fill_color COLORS[:background]
          pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 50
          pdf.fill_color '000000'

          pdf.move_down 15
          pdf.font_size 11 do
            pdf.text @insights['recommendation'], align: :center, style: :bold, color: COLORS[:primary]
          end
          pdf.move_down 15
        end
      end

      if @insights['time_to_sell_estimate'].present?
        pdf.move_down 10
        pdf.text "Estimated Time to Sell: #{@insights['time_to_sell_estimate']}", size: 11, color: COLORS[:light_text], align: :center
      end
    end

    def render_footer(pdf)
      pdf.move_down 30

      pdf.font_size 9 do
        pdf.text "Disclaimer: This CMA report is intended for informational purposes only. The suggested price range is based on comparable sales and market analysis but should not be considered a formal appraisal. Property values can be affected by many factors not fully captured in this analysis. We recommend consulting with a licensed appraiser for a formal property valuation.", color: COLORS[:light_text], leading: 3
      end

      pdf.move_down 20

      pdf.font_size 8 do
        pdf.text "Generated by PropertyWebBuilder on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", color: COLORS[:light_text], align: :center
      end
    end

    def section_header(pdf, title)
      pdf.font_size 16 do
        pdf.text title, style: :bold, color: COLORS[:primary]
      end
      pdf.stroke_color COLORS[:border]
      pdf.stroke_horizontal_line 0, pdf.bounds.width
      pdf.move_down 15
    end

    def format_price(cents)
      return nil unless cents

      currency = @report.suggested_price_currency || 'USD'
      symbol = case currency
               when 'USD' then '$'
               when 'EUR' then '€'
               when 'GBP' then '£'
               else currency
               end

      "#{symbol}#{(cents / 100.0).round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end

    def truncate_text(text, length)
      return nil if text.nil?

      text.length > length ? "#{text[0...length]}..." : text
    end

    def attach_pdf(pdf)
      pdf_content = pdf.render

      @report.pdf_file.attach(
        io: StringIO.new(pdf_content),
        filename: @report.pdf_filename,
        content_type: 'application/pdf'
      )
    end
  end
end
