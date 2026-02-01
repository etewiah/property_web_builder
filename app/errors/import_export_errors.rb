# frozen_string_literal: true

# Import/Export related errors
#
# These errors are raised during property import/export operations.
#

# Base class for import errors
class ImportError < ApplicationError
  attr_reader :row_number, :field_name

  def initialize(message = nil, row_number: nil, field_name: nil, details: {})
    @row_number = row_number
    @field_name = field_name

    details[:row_number] = row_number if row_number
    details[:field_name] = field_name if field_name

    super(
      message || "Import failed",
      code: "IMPORT_ERROR",
      details: details,
      http_status: :unprocessable_entity
    )
  end
end

# Raised when import file format is invalid
class ImportFormatError < ImportError
  def initialize(message = nil, expected_format: nil, details: {})
    details[:expected_format] = expected_format if expected_format

    super(
      message || "Invalid import file format",
      details: details
    )
    @code = "IMPORT_FORMAT_ERROR"
  end
end

# Raised when import data validation fails
class ImportValidationError < ImportError
  attr_reader :validation_errors

  def initialize(message = nil, row_number: nil, validation_errors: [], details: {})
    @validation_errors = validation_errors
    details[:validation_errors] = validation_errors if validation_errors.any?

    super(
      message || "Import validation failed",
      row_number: row_number,
      details: details
    )
    @code = "IMPORT_VALIDATION_ERROR"
  end
end

# Base class for export errors
class ExportError < ApplicationError
  def initialize(message = nil, details: {})
    super(
      message || "Export failed",
      code: "EXPORT_ERROR",
      details: details,
      http_status: :internal_server_error
    )
  end
end

# Raised when export format is not supported
class ExportFormatNotSupportedError < ExportError
  def initialize(format = nil, supported_formats: [], details: {})
    details[:requested_format] = format if format
    details[:supported_formats] = supported_formats if supported_formats.any?

    super(
      format ? "Export format '#{format}' is not supported" : "Export format not supported",
      details: details
    )
    @code = "EXPORT_FORMAT_NOT_SUPPORTED"
    @http_status = :bad_request
  end
end
