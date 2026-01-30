# frozen_string_literal: true

require_dependency 'pwb/application_controller'

module Pwb
  module Reports
    # Public controller for viewing shared CMA reports.
    #
    # Accessed via /cma/:share_token route.
    # No authentication required - reports are accessed by share token.
    #
    class PublicCmaController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:show]

      def show
        @report = Pwb::MarketReport
                    .where(website_id: @current_website&.id)
                    .where(status: 'shared')
                    .find_by(share_token: params[:share_token])

        if @report.nil?
          render_not_found
          return
        end

        # Record the view
        @report.record_view!

        # Set page title for SEO
        @page_title = @report.title

        respond_to do |format|
          format.html { render layout: 'pwb/application' }
          format.json { render json: report_json }
        end
      end

      def pdf
        @report = Pwb::MarketReport
                    .where(website_id: @current_website&.id)
                    .where(status: 'shared')
                    .find_by(share_token: params[:share_token])

        if @report.nil?
          render_not_found
          return
        end

        # Generate PDF if not ready
        unless @report.pdf_ready?
          ::Reports::PdfGenerator.new(@report).generate
          @report.reload
        end

        if @report.pdf_ready?
          redirect_to rails_blob_url(@report.pdf_file, disposition: 'inline'), allow_other_host: true
        else
          render plain: "PDF not available", status: :not_found
        end
      end

      private

      def render_not_found
        respond_to do |format|
          format.html { render plain: "Report not found or no longer shared", status: :not_found }
          format.json { render json: { success: false, error: "Report not found or no longer shared" }, status: :not_found }
        end
      end

      def report_json
        {
          success: true,
          report: {
            reference_number: @report.reference_number,
            title: @report.title,
            generated_at: @report.generated_at&.iso8601,
            subject_property: subject_property_json,
            suggested_price: @report.suggested_price_range,
            comparables: @report.comparable_properties,
            statistics: @report.market_statistics,
            insights: @report.ai_insights,
            branding: @report.branding,
            location: {
              city: @report.city,
              region: @report.region,
              postal_code: @report.postal_code
            }
          }.compact
        }
      end

      def subject_property_json
        return nil unless @report.subject_property

        prop = @report.subject_property
        {
          address: [prop.street_address, prop.city, prop.postal_code].compact.join(', '),
          property_type: prop.prop_type_key,
          bedrooms: prop.count_bedrooms,
          bathrooms: prop.count_bathrooms,
          constructed_area: prop.constructed_area,
          year_built: prop.year_construction
        }
      end
    end
  end
end
