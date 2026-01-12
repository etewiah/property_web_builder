# frozen_string_literal: true

module ApiPublic
  module V1
    # Lightweight search facets endpoint for filter counts
    # Returns counts per filter value without full search results
    class SearchFacetsController < BaseController
      # GET /api_public/v1/search/facets?sale_or_rental=sale
      def index
        website = Pwb::Current.website
        base_scope = website.listed_properties.visible

        # Apply sale/rent filter if specified
        base_scope = apply_sale_rental_filter(base_scope)

        render json: {
          total_count: base_scope.count,
          property_types: facet_counts(base_scope, :prop_type_key),
          zones: facet_counts(base_scope, :zone),
          localities: facet_counts(base_scope, :locality),
          bedrooms: facet_counts(base_scope, :count_bedrooms),
          bathrooms: facet_counts(base_scope, :count_bathrooms),
          price_ranges: price_range_facets(base_scope, params[:sale_or_rental])
        }
      end

      private

      def apply_sale_rental_filter(scope)
        case params[:sale_or_rental]
        when "rent", "rental"
          scope.respond_to?(:for_rent) ? scope.for_rent : scope.where(for_rent: true)
        when "sale"
          scope.respond_to?(:for_sale) ? scope.for_sale : scope.where(for_sale: true)
        else
          scope
        end
      end

      def facet_counts(scope, field)
        scope.where.not(field => [nil, ""])
             .group(field)
             .count
             .transform_keys(&:to_s)
             .sort_by { |_k, v| -v }
             .to_h
      end

      def price_range_facets(scope, sale_or_rental)
        price_field = if %w[rent rental].include?(sale_or_rental)
                        :price_rental_monthly_current_cents
                      else
                        :price_sale_current_cents
                      end

        # Check if the field exists on the model
        return [] unless scope.column_names.include?(price_field.to_s)

        ranges = price_ranges_for(sale_or_rental)

        ranges.map do |range|
          query = scope.where("#{price_field} >= ?", range[:min])
          query = query.where("#{price_field} < ?", range[:max]) if range[:max]

          { label: range[:label], count: query.count, min: range[:min], max: range[:max] }
        end
      end

      def price_ranges_for(sale_or_rental)
        if %w[rent rental].include?(sale_or_rental)
          [
            { label: "< €500/mo", min: 0, max: 500_00 },
            { label: "€500 - €1,000/mo", min: 500_00, max: 1_000_00 },
            { label: "€1,000 - €2,000/mo", min: 1_000_00, max: 2_000_00 },
            { label: "€2,000 - €3,500/mo", min: 2_000_00, max: 3_500_00 },
            { label: "> €3,500/mo", min: 3_500_00, max: nil }
          ]
        else
          [
            { label: "< €100k", min: 0, max: 100_000_00 },
            { label: "€100k - €250k", min: 100_000_00, max: 250_000_00 },
            { label: "€250k - €500k", min: 250_000_00, max: 500_000_00 },
            { label: "€500k - €1M", min: 500_000_00, max: 1_000_000_00 },
            { label: "> €1M", min: 1_000_000_00, max: nil }
          ]
        end
      end
    end
  end
end
