# frozen_string_literal: true

module ApiManage
  module V1
    module Reports
      # API endpoint for CMA (Comparative Market Analysis) reports.
      #
      # Endpoints:
      #   GET    /api_manage/v1/:locale/reports/cmas           - List all CMAs
      #   POST   /api_manage/v1/:locale/reports/cmas           - Generate a new CMA
      #   GET    /api_manage/v1/:locale/reports/cmas/:id       - Show a specific CMA
      #   DELETE /api_manage/v1/:locale/reports/cmas/:id       - Delete a CMA
      #   GET    /api_manage/v1/:locale/reports/cmas/:id/pdf   - Download CMA as PDF
      #   POST   /api_manage/v1/:locale/reports/cmas/:id/share - Generate share link
      #
      class CmasController < ::ApiManage::V1::BaseController
        before_action :set_report, only: [:show, :destroy, :pdf, :share]

        # GET /api_manage/v1/:locale/reports/cmas
        def index
          reports = Pwb::MarketReport
                      .where(website_id: current_website&.id)
                      .cmas
                      .recent
                      .limit(50)

          render json: {
            success: true,
            reports: reports.map { |r| serialize_report(r) }
          }
        end

        # POST /api_manage/v1/:locale/reports/cmas
        def create
          property = find_property

          generator = ::Reports::CmaGenerator.new(
            property: property,
            website: current_website,
            user: current_user,
            options: cma_options
          )

          result = generator.generate

          if result.success?
            render json: {
              success: true,
              report: serialize_report(result.report, include_details: true),
              comparable_count: result.comparables&.length || 0,
              message: result.error # May contain warnings like "No comparables found"
            }, status: :created
          else
            render json: {
              success: false,
              error: result.error,
              report: result.report ? serialize_report(result.report) : nil
            }, status: :unprocessable_entity
          end
        rescue ::Ai::ConfigurationError => e
          render json: {
            success: false,
            error: "AI is not configured: #{e.message}",
            provider: e.provider,
            model: e.model
          }.compact, status: :service_unavailable
        rescue ::Ai::RateLimitError => e
          render json: {
            success: false,
            error: "Rate limit exceeded for #{e.provider || 'AI provider'}. Please try again later.",
            retry_after: e.retry_after,
            provider: e.provider,
            model: e.model
          }.compact, status: :too_many_requests
        end

        # GET /api_manage/v1/:locale/reports/cmas/:id
        def show
          render json: {
            success: true,
            report: serialize_report(@report, include_details: true)
          }
        end

        # DELETE /api_manage/v1/:locale/reports/cmas/:id
        def destroy
          @report.destroy!

          render json: {
            success: true,
            message: "Report deleted successfully"
          }
        end

        # GET /api_manage/v1/:locale/reports/cmas/:id/pdf
        def pdf
          unless @report.pdf_ready?
            # Try to generate PDF on the fly
            ::Reports::PdfGenerator.new(@report).generate
            @report.reload
          end

          if @report.pdf_ready?
            redirect_to @report.pdf_file.url, allow_other_host: true
          else
            render json: {
              success: false,
              error: "PDF not available"
            }, status: :not_found
          end
        end

        # POST /api_manage/v1/:locale/reports/cmas/:id/share
        def share
          unless @report.completed? || @report.shared?
            return render json: {
              success: false,
              error: "Report must be completed before sharing"
            }, status: :unprocessable_entity
          end

          @report.mark_shared! unless @report.shared?

          share_url = build_share_url(@report)

          render json: {
            success: true,
            share_token: @report.share_token,
            share_url: share_url,
            shared_at: @report.shared_at&.iso8601
          }
        end

        private

        def set_report
          @report = Pwb::MarketReport
                      .where(website_id: current_website&.id)
                      .find(params[:id])
        end

        def find_property
          property_id = params[:property_id] || params.dig(:cma, :property_id)

          raise ActionController::ParameterMissing, :property_id unless property_id

          Pwb::RealtyAsset
            .where(website_id: current_website&.id)
            .find(property_id)
        end

        def cma_options
          options = {}

          # Search parameters
          options[:radius_km] = params[:radius_km].to_f if params[:radius_km].present?
          options[:months_back] = params[:months_back].to_i if params[:months_back].present?
          options[:max_comparables] = params[:max_comparables].to_i if params[:max_comparables].present?

          # Report options
          options[:title] = params[:title] if params[:title].present?
          options[:generate_pdf] = params[:generate_pdf] != 'false'

          # Branding
          if params[:branding].present?
            options[:branding] = params[:branding].to_unsafe_h
          end

          options
        end

        def current_user
          # TODO: Get current user from authentication
          nil
        end

        def build_share_url(report)
          # Build a public share URL
          host = request.host
          port = request.port if request.port != 80 && request.port != 443
          protocol = request.protocol

          base = "#{protocol}#{host}"
          base += ":#{port}" if port

          "#{base}/reports/shared/#{report.share_token}"
        end

        def serialize_report(report, include_details: false)
          data = {
            id: report.id,
            reference_number: report.reference_number,
            title: report.title,
            report_type: report.report_type,
            status: report.status,
            created_at: report.created_at.iso8601,
            updated_at: report.updated_at.iso8601,
            generated_at: report.generated_at&.iso8601,
            pdf_ready: report.pdf_ready?,
            shared: report.shared?,
            share_token: report.share_token,
            view_count: report.view_count
          }

          if include_details
            data.merge!(
              subject_property: serialize_subject(report),
              suggested_price: report.suggested_price_range,
              comparables: report.comparable_properties,
              comparable_count: report.comparable_count,
              statistics: report.market_statistics,
              insights: report.ai_insights,
              branding: report.branding,
              location: {
                city: report.city,
                region: report.region,
                postal_code: report.postal_code,
                latitude: report.latitude,
                longitude: report.longitude,
                radius_km: report.radius_km
              }
            )
          end

          data.compact
        end

        def serialize_subject(report)
          return nil unless report.subject_property

          prop = report.subject_property
          {
            id: prop.id,
            reference: prop.reference,
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
end
