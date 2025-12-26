# frozen_string_literal: true

module SiteAdmin
  class PropertyImportExportController < SiteAdminController
    before_action :set_website

    def index
      @property_count = current_website.realty_assets.count
      @active_listings_count = Pwb::ListedProperty.where(website_id: current_website.id).count
    end

    def import
      unless params[:file].present?
        redirect_to site_admin_property_import_export_path, alert: 'Please select a CSV file to import.'
        return
      end

      file = params[:file]
      
      # Validate file type
      unless valid_csv_file?(file)
        redirect_to site_admin_property_import_export_path, alert: 'Invalid file type. Please upload a CSV file.'
        return
      end

      options = {
        update_existing: params[:update_existing] == '1',
        skip_duplicates: params[:skip_duplicates] != '0',
        default_currency: params[:default_currency].presence || 'EUR',
        create_visible: params[:create_visible] == '1',
        dry_run: params[:dry_run] == '1'
      }

      result = Pwb::PropertyBulkImportService.new(
        file: file.tempfile,
        website: current_website,
        options: options
      ).import

      if result.success?
        flash[:notice] = build_success_message(result, options[:dry_run])
      else
        flash[:alert] = build_error_message(result)
      end

      # Store detailed results in session for display
      session[:import_result] = {
        success: result.success?,
        imported_count: result.imported.size,
        error_count: result.errors.size,
        skipped_count: result.skipped.size,
        total_rows: result.total_rows,
        errors: result.errors.first(20), # Limit stored errors
        skipped: result.skipped.first(20),
        dry_run: options[:dry_run]
      }

      redirect_to site_admin_property_import_export_path
    end

    def export
      format = params[:format] || 'csv'
      
      options = {
        include_inactive: params[:include_inactive] == '1',
        include_archived: params[:include_archived] == '1'
      }

      csv_data = Pwb::PropertyExportService.new(
        website: current_website,
        options: options
      ).export

      filename = "properties_#{current_website.subdomain}_#{Date.current.iso8601}.csv"
      
      send_data csv_data,
                filename: filename,
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    end

    def download_template
      template_csv = generate_template_csv
      filename = "property_import_template.csv"
      
      send_data template_csv,
                filename: filename,
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    end

    def clear_results
      session.delete(:import_result)
      redirect_to site_admin_property_import_export_path
    end

    private

    def set_website
      @website = current_website
    end

    def valid_csv_file?(file)
      return false unless file.respond_to?(:content_type)
      
      valid_types = [
        'text/csv',
        'text/plain',
        'application/csv',
        'application/vnd.ms-excel',
        'text/comma-separated-values'
      ]
      
      valid_types.include?(file.content_type) || 
        file.original_filename&.end_with?('.csv', '.tsv', '.txt')
    end

    def build_success_message(result, dry_run)
      if dry_run
        "Dry run complete: #{result.imported.size} properties would be imported. " \
        "#{result.skipped.size} would be skipped. " \
        "#{result.errors.size} errors found."
      else
        "Import complete: #{result.imported.size} properties imported successfully. " \
        "#{result.skipped.size} skipped. " \
        "#{result.errors.size} errors."
      end
    end

    def build_error_message(result)
      error_preview = result.errors.first(3).map { |e| e[:error] || e.to_s }.join('; ')
      "Import failed with #{result.errors.size} errors. #{error_preview}"
    end

    def generate_template_csv
      headers = [
        'reference',
        'street_address',
        'city',
        'region',
        'postal_code',
        'country',
        'prop_type_key',
        'count_bedrooms',
        'count_bathrooms',
        'constructed_area',
        'for_sale',
        'for_rent',
        'price_sale',
        'price_rental_monthly',
        'currency',
        'title_en',
        'description_en',
        'visible',
        'features'
      ]

      example_row = [
        'PROP-001',
        '123 Main Street',
        'Barcelona',
        'Catalonia',
        '08001',
        'Spain',
        'apartment',
        '3',
        '2',
        '120',
        'true',
        'false',
        '350000',
        '',
        'EUR',
        'Beautiful apartment in city center',
        'Spacious 3-bedroom apartment with modern finishes and great views.',
        'true',
        'parking,pool,terrace'
      ]

      CSV.generate do |csv|
        csv << headers
        csv << example_row
      end
    end
  end
end
