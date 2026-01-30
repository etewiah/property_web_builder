# frozen_string_literal: true

# Background job to generate PDF files for market reports.
#
# Uses TenantAwareJob to ensure proper multi-tenant context.
#
# Usage:
#   GenerateReportPdfJob.perform_later(report_id: report.id, website_id: website.id)
#
class GenerateReportPdfJob < ApplicationJob
  include TenantAwareJob

  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(report_id:, website_id:)
    set_tenant!(website_id)

    report = Pwb::MarketReport.find(report_id)

    Rails.logger.info "[GenerateReportPdfJob] Generating PDF for report #{report.reference_number}"

    Reports::PdfGenerator.new(report).generate

    Rails.logger.info "[GenerateReportPdfJob] PDF generated successfully for report #{report.reference_number}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[GenerateReportPdfJob] Report not found: #{report_id}"
    # Don't retry if the record is not found
    raise
  rescue StandardError => e
    Rails.logger.error "[GenerateReportPdfJob] Error generating PDF: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  ensure
    clear_tenant!
  end
end
