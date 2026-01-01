# frozen_string_literal: true

module Pwb
  module ExternalFeed
    # Normalized search result wrapper.
    # Provides consistent pagination and metadata for search results
    # regardless of the provider.
    class NormalizedSearchResult
      attr_accessor :properties        # Array<NormalizedProperty>
      attr_accessor :total_count       # Integer - Total matching properties
      attr_accessor :page              # Integer - Current page (1-indexed)
      attr_accessor :per_page          # Integer - Results per page
      attr_accessor :total_pages       # Integer - Total pages
      attr_accessor :query_params      # Hash - The params used for this search
      attr_accessor :provider          # Symbol - Provider name
      attr_accessor :fetched_at        # DateTime - When results were fetched
      attr_accessor :error             # String - Error message if search failed

      # Initialize with attributes
      # @param attrs [Hash] Result attributes
      def initialize(attrs = {})
        @properties = []
        @page = 1
        @per_page = 24
        @total_count = 0
        @query_params = {}

        attrs.each do |key, value|
          setter = "#{key}="
          send(setter, value) if respond_to?(setter)
        end

        @fetched_at ||= Time.current
        calculate_total_pages
      end

      # Convert to hash for JSON serialization
      # @return [Hash]
      def to_h
        {
          properties: properties.map(&:to_h),
          total_count: total_count,
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          query_params: query_params,
          provider: provider,
          fetched_at: fetched_at&.iso8601,
          error: error
        }
      end

      # Alias for to_h
      def as_json(options = nil)
        to_h
      end

      # Check if results are empty
      # @return [Boolean]
      def empty?
        properties.empty?
      end

      # Check if there are any results
      # @return [Boolean]
      def any?
        properties.any?
      end

      # Number of properties in this page
      # @return [Integer]
      def count
        properties.size
      end

      # Alias for count
      def size
        count
      end

      # Alias for page (for view compatibility)
      # @return [Integer]
      def current_page
        page
      end

      # Check if this is the first page
      # @return [Boolean]
      def first_page?
        page <= 1
      end

      # Check if this is the last page
      # @return [Boolean]
      def last_page?
        page >= total_pages
      end

      # Get next page number
      # @return [Integer, nil]
      def next_page
        last_page? ? nil : page + 1
      end

      # Get previous page number
      # @return [Integer, nil]
      def prev_page
        first_page? ? nil : page - 1
      end

      # Check if there's a next page
      # @return [Boolean]
      def has_next_page?
        !last_page?
      end

      # Check if there's a previous page
      # @return [Boolean]
      def has_prev_page?
        !first_page?
      end

      # Get page range for pagination display
      # @param window [Integer] Number of pages to show on each side
      # @return [Range]
      def page_range(window: 2)
        start_page = [page - window, 1].max
        end_page = [page + window, total_pages].min
        (start_page..end_page)
      end

      # Check if search had an error
      # @return [Boolean]
      def error?
        error.present?
      end

      # Check if search was successful
      # @return [Boolean]
      def success?
        !error?
      end

      # Iterate over properties
      def each(&block)
        properties.each(&block)
      end

      # Map over properties
      def map(&block)
        properties.map(&block)
      end

      # Select properties
      def select(&block)
        properties.select(&block)
      end

      # First property
      # @return [NormalizedProperty, nil]
      def first
        properties.first
      end

      # Last property
      # @return [NormalizedProperty, nil]
      def last
        properties.last
      end

      # Get offset for current page (0-indexed)
      # @return [Integer]
      def offset
        (page - 1) * per_page
      end

      # Get the range of results shown
      # @return [String] e.g., "1-24 of 150"
      def results_range
        return "0 of 0" if empty?

        start_num = offset + 1
        end_num = [offset + per_page, total_count].min
        "#{start_num}-#{end_num} of #{total_count}"
      end

      private

      def calculate_total_pages
        return @total_pages if @total_pages && @total_pages > 0
        return 0 if total_count.nil? || per_page.nil? || per_page.zero?

        @total_pages = (total_count.to_f / per_page).ceil
      end
    end
  end
end
