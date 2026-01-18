# frozen_string_literal: true

module ApiPublic
  # Concern for standardized API response envelopes
  # Provides consistent response format across all endpoints
  #
  # Standard envelope format:
  # {
  #   "data": { ... } | [...],
  #   "meta": { "total": 100, "page": 1, ... },
  #   "_links": { "self": "/...", "next": "/..." },
  #   "_errors": []
  # }
  module ResponseEnvelope
    extend ActiveSupport::Concern

    private

    # Render a standardized response envelope
    #
    # @param data [Hash, Array] The primary response data
    # @param meta [Hash] Pagination and metadata (optional)
    # @param links [Hash] HATEOAS-style links (optional)
    # @param errors [Array] Partial failure errors (optional)
    # @param status [Symbol, Integer] HTTP status (default: :ok)
    def render_envelope(data:, meta: nil, links: nil, errors: nil, status: :ok)
      response = { data: data }
      response[:meta] = meta if meta.present?
      response[:_links] = links if links.present?
      response[:_errors] = errors if errors.present? && errors.any?

      render json: response, status: status
    end

    # Build pagination meta from a collection
    #
    # @param total [Integer] Total count of items
    # @param page [Integer] Current page number
    # @param per_page [Integer] Items per page
    # @return [Hash] Pagination metadata
    def build_pagination_meta(total:, page:, per_page:)
      total_pages = per_page.positive? ? (total.to_f / per_page).ceil : 0

      {
        total: total,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    end

    # Build HATEOAS-style pagination links
    #
    # @param base_path [String] Base URL path for the resource
    # @param page [Integer] Current page number
    # @param total_pages [Integer] Total number of pages
    # @param query_params [Hash] Additional query parameters
    # @return [Hash] Navigation links
    def build_pagination_links(base_path:, page:, total_pages:, query_params: {})
      links = {
        self: build_page_url(base_path, page, query_params)
      }

      links[:first] = build_page_url(base_path, 1, query_params) if page > 1
      links[:prev] = build_page_url(base_path, page - 1, query_params) if page > 1
      links[:next] = build_page_url(base_path, page + 1, query_params) if page < total_pages
      links[:last] = build_page_url(base_path, total_pages, query_params) if page < total_pages

      links
    end

    # Build a URL with page parameter
    def build_page_url(base_path, page, query_params)
      params = query_params.merge(page: page)
      query_string = params.to_query
      query_string.present? ? "#{base_path}?#{query_string}" : base_path
    end

    # Render a success response with optional message
    def render_success(message: nil, data: nil, status: :ok)
      response = { success: true }
      response[:message] = message if message
      response[:data] = data if data

      render json: response, status: status
    end

    # Render a created response (201)
    def render_created(data:, location: nil)
      response = { data: data }
      headers["Location"] = location if location

      render json: response, status: :created
    end
  end
end
