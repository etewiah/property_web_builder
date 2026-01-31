# frozen_string_literal: true

module SiteAdmin
  # Controller for managing CMA (Comparative Market Analysis) reports.
  #
  # Provides functionality to:
  # - List and view CMA reports
  # - Generate new CMAs for properties
  # - Download PDFs and share reports
  # - Regenerate AI insights
  class CmaReportsController < ::SiteAdminController
    before_action :set_report, only: %i[show destroy regenerate share download]

    def index
      @reports = current_website.market_reports
                                .cmas
                                .includes(:subject_property, :user)
                                .recent

      # Apply filters
      @reports = @reports.where(status: params[:status]) if params[:status].present?

      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @reports = @reports.where(
          'title ILIKE :term OR reference_number ILIKE :term OR city ILIKE :term',
          term: search_term
        )
      end

      @pagy, @reports = pagy(@reports, items: 20)
    end

    def show
      @subject_property = @report.subject_property
      @comparables = @report.comparable_properties || []
      @statistics = @report.market_statistics || {}
      @insights = @report.ai_insights || {}
    end

    def new
      @report = current_website.market_reports.new(report_type: 'cma')
      @properties = available_properties
    end

    def create
      property = find_property

      unless property
        flash[:alert] = 'Please select a property'
        @properties = available_properties
        @report = current_website.market_reports.new(report_type: 'cma')
        render :new, status: :unprocessable_entity
        return
      end

      generator = ::Reports::CmaGenerator.new(
        property: property,
        website: current_website,
        user: current_user,
        options: cma_options
      )

      result = generator.generate

      if result.success?
        redirect_to site_admin_cma_report_path(result.report),
                    notice: 'CMA report generated successfully'
      else
        redirect_to site_admin_cma_reports_path,
                    alert: "Failed to generate report: #{result.error}"
      end
    rescue ::Ai::ConfigurationError => e
      redirect_to site_admin_integrations_path,
                  alert: "AI is not configured. Please set up an AI integration first."
    rescue ::Ai::RateLimitError => e
      provider_info = e.provider ? " (#{e.provider})" : ""
      redirect_to site_admin_cma_reports_path,
                  alert: "Rate limit exceeded#{provider_info}. Please try again in #{e.retry_after || 60} seconds."
    end

    def destroy
      @report.destroy!
      redirect_to site_admin_cma_reports_path,
                  notice: "Report #{@report.reference_number} deleted"
    end

    def regenerate
      unless @report.subject_property
        redirect_to site_admin_cma_report_path(@report),
                    alert: 'Cannot regenerate: no subject property linked'
        return
      end

      generator = ::Reports::CmaGenerator.new(
        property: @report.subject_property,
        website: current_website,
        user: current_user,
        options: {
          radius_km: @report.radius_km || 2,
          generate_pdf: true,
          branding: @report.branding
        }
      )

      result = generator.generate

      if result.success?
        # Archive old report
        @report.update!(status: 'archived') if @report.id != result.report.id

        redirect_to site_admin_cma_report_path(result.report),
                    notice: 'Report regenerated successfully'
      else
        redirect_to site_admin_cma_report_path(@report),
                    alert: "Failed to regenerate: #{result.error}"
      end
    rescue ::Ai::ConfigurationError, ::Ai::RateLimitError => e
      provider_info = e.provider ? " (provider: #{e.provider})" : ""
      redirect_to site_admin_cma_report_path(@report),
                  alert: "#{e.message}#{provider_info}"
    end

    def share
      unless @report.completed? || @report.shared?
        redirect_to site_admin_cma_report_path(@report),
                    alert: 'Report must be completed before sharing'
        return
      end

      @report.mark_shared! unless @report.shared?

      share_url = public_cma_url(@report.share_token)

      redirect_to site_admin_cma_report_path(@report),
                  notice: "Report shared! URL: #{share_url}"
    end

    def download
      unless @report.pdf_ready?
        # Generate PDF on the fly if not ready
        ::Reports::PdfGenerator.new(@report).generate
        @report.reload
      end

      if @report.pdf_ready?
        redirect_to rails_blob_path(@report.pdf_file, disposition: 'attachment'),
                    allow_other_host: true
      else
        redirect_to site_admin_cma_report_path(@report),
                    alert: 'PDF generation failed. Please try again.'
      end
    end

    private

    def set_report
      @report = current_website.market_reports.find(params[:id])
    end

    def find_property
      property_id = params.dig(:cma_report, :property_id) || params[:property_id]
      return nil if property_id.blank?

      current_website.realty_assets.find_by(id: property_id)
    end

    def cma_options
      options = {}

      if params[:cma_report].present?
        cma_params = params[:cma_report]
        options[:radius_km] = cma_params[:radius_km].to_f if cma_params[:radius_km].present?
        options[:months_back] = cma_params[:months_back].to_i if cma_params[:months_back].present?
        options[:max_comparables] = cma_params[:max_comparables].to_i if cma_params[:max_comparables].present?
        options[:title] = cma_params[:title] if cma_params[:title].present?
      end

      options[:generate_pdf] = true
      options
    end

    def available_properties
      current_website.realty_assets
                     .includes(:sale_listings, :rental_listings)
                     .order(:street_address)
                     .limit(100)
    end
  end
end
