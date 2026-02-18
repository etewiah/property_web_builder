# frozen_string_literal: true

module SiteAdmin
  # Controller for importing properties from external URLs.
  # Allows site admins to paste a property URL, scrape the data,
  # and create a new property from the extracted information.
  class PropertyUrlImportController < SiteAdminController
    before_action :set_scraped_property, only: [:preview, :confirm_import]

    # GET /site_admin/property_url_import/new
    # Show the URL input form
    def new
      @scraped_property = nil
      @pws_enabled = Pwb::ExternalScraperClient.enabled?
      @supported_portals = Pwb::ExternalScraperClient.supported_portals if @pws_enabled
    end

    # POST /site_admin/property_url_import
    # Attempt to scrape the provided URL
    def create
      url = params[:url].to_s.strip

      if url.blank?
        redirect_to site_admin_property_url_import_path, alert: "Please enter a property URL."
        return
      end

      unless valid_url?(url)
        redirect_to site_admin_property_url_import_path, alert: "Please enter a valid URL."
        return
      end

      # Check for existing scrape/import (duplicate detection)
      existing = Pwb::ScrapedProperty.find_duplicate(url, website: current_website)
      if existing&.already_imported?
        redirect_to site_admin_prop_path(existing.realty_asset),
                    alert: "This property has already been imported from this URL."
        return
      elsif existing&.can_preview?
        # URL was scraped but not imported - offer to continue
        redirect_to site_admin_property_url_import_preview_path(existing),
                    notice: "This URL was previously scraped. You can continue the import."
        return
      end

      service = Pwb::PropertyScraperService.new(url, website: current_website)
      @scraped_property = service.call

      if @scraped_property.scrape_successful?
        redirect_to site_admin_property_url_import_preview_path(@scraped_property),
                    notice: "Property data extracted successfully. Please review before importing."
      else
        # Show manual HTML entry form
        render :manual_html_form
      end
    end

    # POST /site_admin/property_url_import/manual_html
    # Process manually pasted HTML when auto-scraping fails
    def manual_html
      url = params[:url].to_s.strip
      html = params[:raw_html].to_s

      if html.blank?
        @scraped_property = Pwb::ScrapedProperty.find_or_initialize_by(
          website: current_website,
          source_url: url
        )
        flash.now[:alert] = "Please paste the HTML source of the property page."
        render :manual_html_form
        return
      end

      service = Pwb::PropertyScraperService.new(url, website: current_website)
      @scraped_property = service.import_from_manual_html(html)

      redirect_to site_admin_property_url_import_preview_path(@scraped_property),
                  notice: "HTML parsed successfully. Please review the extracted data."
    end

    # GET /site_admin/property_url_import/:id/preview
    # Show extracted data for review before import
    def preview
      unless @scraped_property.can_preview?
        redirect_to site_admin_property_url_import_path,
                    alert: "Unable to preview this property. Please try again."
        return
      end

      @asset_data = @scraped_property.asset_data
      @listing_data = @scraped_property.listing_data
      @images = @scraped_property.images
    end

    # POST /site_admin/property_url_import/:id/confirm
    # Create the actual property from scraped data
    def confirm_import
      if @scraped_property.already_imported?
        redirect_to site_admin_prop_path(@scraped_property.realty_asset),
                    notice: "This property has already been imported."
        return
      end

      # Build overrides from form params
      overrides = build_overrides_from_params

      service = Pwb::PropertyImportFromScrapeService.new(@scraped_property, overrides: overrides)
      result = service.call

      if result.success?
        redirect_to edit_general_site_admin_prop_path(result.realty_asset),
                    notice: "Property imported successfully! You can now edit the details."
      else
        flash.now[:alert] = "Failed to import property: #{result.error}"
        @asset_data = @scraped_property.asset_data
        @listing_data = @scraped_property.listing_data
        @images = @scraped_property.images
        render :preview
      end
    end

    # GET /site_admin/property_url_import/history
    # Show history of scraped properties
    def history
      @scraped_properties = Pwb::ScrapedProperty
        .where(website: current_website)
        .order(created_at: :desc)
        .limit(50)
    end

    # GET /site_admin/property_url_import/batch
    # Show batch import form (CSV or URL list)
    def batch
      @batch_result = nil
      if Pwb::ExternalScraperClient.enabled?
        @pws_status = Pwb::ExternalScraperClient.healthy? ? :healthy : :unhealthy
      end
    end

    # POST /site_admin/property_url_import/batch_process
    # Process batch import
    def batch_process
      urls = extract_urls_from_params
      csv_content = extract_csv_from_params

      if urls.blank? && csv_content.blank?
        flash.now[:alert] = "Please provide URLs or upload a CSV file."
        render :batch
        return
      end

      # For small batches, process synchronously
      # For larger batches, queue a background job
      total_count = urls&.count || count_csv_urls(csv_content)

      if total_count > 10
        # Queue background job
        Pwb::BatchUrlImportJob.perform_later(
          current_website.id,
          urls: urls,
          csv_content: csv_content,
          notify_email: current_user.email
        )

        redirect_to site_admin_property_url_import_history_path,
                    notice: "Batch import started for #{total_count} URLs. You'll receive an email when complete."
      else
        # Process synchronously
        service = Pwb::BatchUrlImportService.new(
          current_website,
          urls: urls,
          csv_content: csv_content
        )

        @batch_result = service.call

        if @batch_result.successful > 0
          flash.now[:notice] = @batch_result.summary
        else
          flash.now[:alert] = @batch_result.summary
        end

        render :batch
      end
    end

    private

    def set_scraped_property
      @scraped_property = Pwb::ScrapedProperty.find(params[:id])

      # Ensure it belongs to the current website
      unless @scraped_property.website_id == current_website.id
        raise ActiveRecord::RecordNotFound
      end
    end

    def valid_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    def build_overrides_from_params
      {
        asset_data: params.permit(
          asset_data: [
            :count_bedrooms, :count_bathrooms, :city, :region,
            :postal_code, :country, :street_address, :prop_type_key,
            :constructed_area, :plot_area
          ]
        )[:asset_data]&.to_h || {},
        listing_data: params.permit(
          listing_data: [
            :title, :description, :price_sale_current, :currency, :visible
          ]
        )[:listing_data]&.to_h || {}
      }
    end

    def extract_urls_from_params
      url_text = params[:urls].to_s.strip
      return nil if url_text.blank?

      url_text.split(/[\n\r]+/).map(&:strip).reject(&:blank?).select { |u| valid_url?(u) }
    end

    def extract_csv_from_params
      csv_file = params[:csv_file]
      return nil unless csv_file.respond_to?(:read)

      csv_file.read
    rescue StandardError
      nil
    end

    def count_csv_urls(csv_content)
      return 0 if csv_content.blank?

      csv_content.lines.count - 1 # Subtract header row
    rescue StandardError
      0
    end
  end
end
