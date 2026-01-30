# frozen_string_literal: true

module Reports
  # Finds comparable properties for a CMA (Comparative Market Analysis).
  #
  # Uses the Pwb::ListedProperty materialized view to find similar properties
  # based on location, property type, size, and features.
  #
  # Each comparable is scored by similarity (100 points base, deductions for differences)
  # and includes price adjustments based on feature differences.
  #
  # Usage:
  #   finder = Reports::ComparablesFinder.new(
  #     subject: realty_asset,
  #     website: website,
  #     options: { radius_km: 2, months_back: 6, max_comparables: 10 }
  #   )
  #   comparables = finder.find
  #
  class ComparablesFinder
    # Price adjustment factors (in cents)
    ADJUSTMENT_FACTORS = {
      bedroom: 15_000_00,    # $15,000 per bedroom difference
      bathroom: 10_000_00,   # $10,000 per bathroom difference
      sqft: 150_00,          # $150 per sqft difference
      year_built: 1_000_00,  # $1,000 per year difference
      garage: 8_000_00       # $8,000 per garage difference
    }.freeze

    # Similarity scoring weights
    SIMILARITY_WEIGHTS = {
      property_type: 20,
      bedrooms: 15,
      bathrooms: 10,
      size: 20,
      location: 20,
      year: 10,
      features: 5
    }.freeze

    DEFAULT_OPTIONS = {
      radius_km: 2,
      months_back: 6,
      max_comparables: 10,
      min_similarity_score: 50
    }.freeze

    Result = Struct.new(:comparables, :total_found, :search_criteria, keyword_init: true)

    def initialize(subject:, website:, options: {})
      @subject = subject
      @website = website
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def find
      candidates = find_candidates
      scored = score_and_adjust(candidates)
      filtered = filter_by_similarity(scored)
      sorted = sort_by_relevance(filtered)
      limited = sorted.take(@options[:max_comparables])

      Result.new(
        comparables: limited,
        total_found: candidates.count,
        search_criteria: search_criteria
      )
    end

    private

    def find_candidates
      scope = base_scope

      # Filter by location (within radius)
      scope = apply_location_filter(scope) if has_coordinates?

      # Filter by property type
      scope = scope.where(prop_type_key: @subject.prop_type_key) if @subject.prop_type_key.present?

      # Filter by listing type (sale vs rental)
      scope = apply_listing_type_filter(scope)

      # Filter by size range (within 30% of subject)
      scope = apply_size_filter(scope) if @subject.constructed_area.to_f > 0

      # Filter by bedroom range (within 1)
      scope = apply_bedroom_filter(scope) if @subject.count_bedrooms.to_i > 0

      # Exclude the subject property itself
      scope = scope.where.not(id: @subject.id)

      scope.to_a
    end

    def base_scope
      Pwb::ListedProperty.where(website_id: @website.id)
                         .where(visible: true)
    end

    def apply_location_filter(scope)
      return scope unless has_coordinates?

      # Use Haversine formula approximation in SQL
      # 1 degree latitude ≈ 111 km
      # 1 degree longitude ≈ 111 km * cos(latitude)
      lat = @subject.latitude
      lng = @subject.longitude
      radius = @options[:radius_km]

      # Simple bounding box filter (more efficient than full distance calc)
      lat_delta = radius / 111.0
      lng_delta = radius / (111.0 * Math.cos(lat * Math::PI / 180))

      scope.where(latitude: (lat - lat_delta)..(lat + lat_delta))
           .where(longitude: (lng - lng_delta)..(lng + lng_delta))
    end

    def apply_listing_type_filter(scope)
      if subject_for_sale?
        scope.where(for_sale: true)
      elsif subject_for_rent?
        scope.where(for_rent: true)
      else
        scope
      end
    end

    def apply_size_filter(scope)
      area = @subject.constructed_area.to_f
      return scope if area <= 0

      min_area = area * 0.7
      max_area = area * 1.3

      scope.where(constructed_area: min_area..max_area)
    end

    def apply_bedroom_filter(scope)
      bedrooms = @subject.count_bedrooms.to_i
      return scope if bedrooms <= 0

      scope.where(count_bedrooms: (bedrooms - 1)..(bedrooms + 1))
    end

    def score_and_adjust(candidates)
      candidates.map do |property|
        similarity_score = calculate_similarity(property)
        adjustments = calculate_adjustments(property)
        adjusted_price = calculate_adjusted_price(property, adjustments)

        {
          id: property.id,
          reference: property.reference,
          address: format_address(property),
          city: property.city,
          property_type: property.prop_type_key,
          bedrooms: property.count_bedrooms,
          bathrooms: property.count_bathrooms,
          constructed_area: property.constructed_area,
          year_built: property.year_construction,
          garages: property.count_garages,
          price_cents: get_price_cents(property),
          currency: get_currency(property),
          similarity_score: similarity_score,
          adjustments: adjustments,
          adjusted_price_cents: adjusted_price,
          distance_km: calculate_distance(property),
          photo_url: property.primary_image_url
        }
      end
    end

    def calculate_similarity(property)
      score = 100.0

      # Property type match (20 points)
      if property.prop_type_key != @subject.prop_type_key
        score -= SIMILARITY_WEIGHTS[:property_type]
      end

      # Bedroom difference (15 points, -3 per difference)
      bedroom_diff = (@subject.count_bedrooms.to_i - property.count_bedrooms.to_i).abs
      score -= [bedroom_diff * 3, SIMILARITY_WEIGHTS[:bedrooms]].min

      # Bathroom difference (10 points, -5 per difference)
      bathroom_diff = (@subject.count_bathrooms.to_f - property.count_bathrooms.to_f).abs
      score -= [bathroom_diff * 5, SIMILARITY_WEIGHTS[:bathrooms]].min

      # Size difference (20 points, proportional)
      if @subject.constructed_area.to_f > 0 && property.constructed_area.to_f > 0
        size_ratio = property.constructed_area / @subject.constructed_area
        size_diff_pct = (1 - size_ratio).abs * 100
        score -= [size_diff_pct / 5, SIMILARITY_WEIGHTS[:size]].min
      end

      # Location distance (20 points, -4 per km)
      if has_coordinates? && property.latitude.present?
        distance = calculate_distance(property)
        score -= [distance * 4, SIMILARITY_WEIGHTS[:location]].min
      end

      # Year built difference (10 points, -1 per 5 years)
      if @subject.year_construction.to_i > 0 && property.year_construction.to_i > 0
        year_diff = (@subject.year_construction - property.year_construction).abs
        score -= [year_diff / 5, SIMILARITY_WEIGHTS[:year]].min
      end

      [score.round(1), 0].max
    end

    def calculate_adjustments(property)
      adjustments = {}

      # Bedroom adjustment
      bedroom_diff = @subject.count_bedrooms.to_i - property.count_bedrooms.to_i
      if bedroom_diff != 0
        adjustments[:bedrooms] = {
          difference: bedroom_diff,
          adjustment_cents: bedroom_diff * ADJUSTMENT_FACTORS[:bedroom]
        }
      end

      # Bathroom adjustment
      bathroom_diff = @subject.count_bathrooms.to_f - property.count_bathrooms.to_f
      if bathroom_diff.abs >= 0.5
        adjustments[:bathrooms] = {
          difference: bathroom_diff,
          adjustment_cents: (bathroom_diff * ADJUSTMENT_FACTORS[:bathroom]).round
        }
      end

      # Size adjustment (per sqft/sqm)
      if @subject.constructed_area.to_f > 0 && property.constructed_area.to_f > 0
        size_diff = @subject.constructed_area - property.constructed_area
        if size_diff.abs > 10 # Only adjust for significant differences
          adjustments[:size] = {
            difference: size_diff.round,
            adjustment_cents: (size_diff * ADJUSTMENT_FACTORS[:sqft]).round
          }
        end
      end

      # Year built adjustment
      if @subject.year_construction.to_i > 0 && property.year_construction.to_i > 0
        year_diff = @subject.year_construction - property.year_construction
        if year_diff.abs > 5 # Only adjust for significant differences
          adjustments[:year_built] = {
            difference: year_diff,
            adjustment_cents: (year_diff * ADJUSTMENT_FACTORS[:year_built])
          }
        end
      end

      # Garage adjustment
      garage_diff = @subject.count_garages.to_i - property.count_garages.to_i
      if garage_diff != 0
        adjustments[:garages] = {
          difference: garage_diff,
          adjustment_cents: garage_diff * ADJUSTMENT_FACTORS[:garage]
        }
      end

      adjustments
    end

    def calculate_adjusted_price(property, adjustments)
      base_price = get_price_cents(property)
      return nil unless base_price&.positive?

      total_adjustment = adjustments.values.sum { |adj| adj[:adjustment_cents] }
      base_price + total_adjustment
    end

    def filter_by_similarity(scored)
      min_score = @options[:min_similarity_score]
      scored.select { |comp| comp[:similarity_score] >= min_score }
    end

    def sort_by_relevance(comparables)
      comparables.sort_by { |comp| -comp[:similarity_score] }
    end

    def has_coordinates?
      @subject.latitude.present? && @subject.longitude.present?
    end

    def calculate_distance(property)
      return nil unless has_coordinates? && property.latitude.present? && property.longitude.present?

      # Haversine formula
      lat1 = @subject.latitude * Math::PI / 180
      lat2 = property.latitude * Math::PI / 180
      delta_lat = (property.latitude - @subject.latitude) * Math::PI / 180
      delta_lng = (property.longitude - @subject.longitude) * Math::PI / 180

      a = Math.sin(delta_lat / 2)**2 +
          Math.cos(lat1) * Math.cos(lat2) * Math.sin(delta_lng / 2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      (6371 * c).round(2) # Earth's radius in km
    end

    def format_address(property)
      [property.street_address, property.city, property.postal_code]
        .compact
        .reject(&:blank?)
        .join(', ')
    end

    def subject_for_sale?
      @subject.respond_to?(:for_sale?) && @subject.for_sale?
    end

    def subject_for_rent?
      @subject.respond_to?(:for_rent?) && @subject.for_rent?
    end

    def get_price_cents(property)
      if property.for_sale? && property.price_sale_current_cents.to_i > 0
        property.price_sale_current_cents
      elsif property.for_rent? && property.price_rental_monthly_current_cents.to_i > 0
        property.price_rental_monthly_current_cents
      end
    end

    def get_currency(property)
      if property.for_sale?
        property.price_sale_current_currency || 'USD'
      else
        property.price_rental_monthly_current_currency || 'USD'
      end
    end

    def search_criteria
      {
        radius_km: @options[:radius_km],
        months_back: @options[:months_back],
        max_comparables: @options[:max_comparables],
        property_type: @subject.prop_type_key,
        bedrooms: @subject.count_bedrooms,
        bathrooms: @subject.count_bathrooms,
        size_sqft: @subject.constructed_area,
        location: {
          city: @subject.city,
          region: @subject.region,
          latitude: @subject.latitude,
          longitude: @subject.longitude
        }
      }
    end
  end
end
