# frozen_string_literal: true

module ApiPublic
  # Custom error classes for standardized error responses
  module Errors
    # Base error class for all API errors
    class ApiError < StandardError
      attr_reader :code, :status, :details

      def initialize(message, code: nil, status: :internal_server_error, details: {})
        @code = code || self.class.name.demodulize.underscore.upcase
        @status = status
        @details = details
        super(message)
      end

      def to_h
        {
          code: code,
          message: message,
          status: Rack::Utils.status_code(status),
          details: details.presence
        }.compact
      end
    end

    # 400 Bad Request errors
    class ValidationError < ApiError
      def initialize(message = "Validation failed", details: {})
        super(message, code: "VALIDATION_FAILED", status: :bad_request, details: details)
      end
    end

    class InvalidLocaleError < ApiError
      def initialize(locale)
        super(
          "Unsupported locale: #{locale}",
          code: "INVALID_LOCALE",
          status: :bad_request,
          details: { requested_locale: locale }
        )
      end
    end

    class InvalidSortError < ApiError
      def initialize(sort_param)
        super(
          "Invalid sort parameter: #{sort_param}",
          code: "INVALID_SORT",
          status: :bad_request,
          details: {
            requested_sort: sort_param,
            valid_options: %w[price-asc price-desc price_asc price_desc newest oldest]
          }
        )
      end
    end

    # 404 Not Found errors
    class NotFoundError < ApiError
      def initialize(message = "Resource not found")
        super(message, code: "NOT_FOUND", status: :not_found)
      end
    end

    class PropertyNotFoundError < ApiError
      def initialize(slug_or_id)
        super(
          "Property not found: #{slug_or_id}",
          code: "PROPERTY_NOT_FOUND",
          status: :not_found,
          details: { requested: slug_or_id.to_s }
        )
      end
    end

    class PageNotFoundError < ApiError
      def initialize(slug_or_id)
        super(
          "Page not found: #{slug_or_id}",
          code: "PAGE_NOT_FOUND",
          status: :not_found,
          details: { requested: slug_or_id.to_s }
        )
      end
    end

    class ThemeNotFoundError < ApiError
      def initialize(theme_name)
        super(
          "Theme not found: #{theme_name}",
          code: "THEME_NOT_FOUND",
          status: :not_found,
          details: { requested_theme: theme_name }
        )
      end
    end

    # 403 Forbidden errors
    class ClientRenderingDisabledError < ApiError
      def initialize(rendering_mode)
        super(
          "Client rendering is not enabled for this website",
          code: "CLIENT_RENDERING_DISABLED",
          status: :forbidden,
          details: { current_mode: rendering_mode }
        )
      end
    end

    # 429 Rate Limited errors
    class RateLimitedError < ApiError
      attr_reader :retry_after

      def initialize(retry_after: 60)
        @retry_after = retry_after
        super(
          "Rate limit exceeded. Try again in #{retry_after} seconds.",
          code: "RATE_LIMITED",
          status: :too_many_requests,
          details: { retry_after: retry_after }
        )
      end
    end

    # 500 Server errors
    class InternalError < ApiError
      def initialize(message = "An unexpected error occurred")
        super(message, code: "INTERNAL_ERROR", status: :internal_server_error)
      end
    end

    class DatabaseError < ApiError
      def initialize
        super(
          "Database connection error. Please try again.",
          code: "DATABASE_ERROR",
          status: :internal_server_error
        )
      end
    end
  end
end
