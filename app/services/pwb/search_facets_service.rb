# frozen_string_literal: true

module Pwb
  # Service for calculating faceted search counts
  # Provides counts for each filter option based on current search results
  #
  # Usage:
  #   facets = SearchFacetsService.calculate(
  #     scope: @properties,
  #     website: @current_website,
  #     operation_type: "for_sale"
  #   )
  #   # => { property_types: [...], property_states: [...], features: [...], amenities: [...] }
  #
  class SearchFacetsService
    class << self
      # Calculate all facets for the given scope
      #
      # @param scope [ActiveRecord::Relation] The current filtered property scope
      # @param website [Pwb::Website] The current website
      # @param operation_type [String] "for_sale" or "for_rent"
      # @return [Hash] Facet data with counts
      def calculate(scope:, website:, operation_type: nil)
        {
          property_types: calculate_property_types(scope, website),
          property_states: calculate_property_states(scope, website),
          features: calculate_features(scope, website),
          amenities: calculate_amenities(scope, website),
          bedrooms: calculate_bedrooms(scope),
          bathrooms: calculate_bathrooms(scope)
        }
      end

      # Calculate counts for property types
      def calculate_property_types(scope, website)
        counts = scope.group(:prop_type_key).count

        build_facet_list("property-types", counts, website)
      end

      # Calculate counts for property states
      def calculate_property_states(scope, website)
        counts = scope.group(:prop_state_key).count

        build_facet_list("property-states", counts, website)
      end

      # Calculate counts for features (permanent physical attributes)
      def calculate_features(scope, website)
        feature_keys = FieldKey.by_tag("property-features").pluck(:global_key)
        return [] if feature_keys.empty?

        # Get property IDs from the current scope
        property_ids = scope.pluck(:id)
        return build_empty_facet_list("property-features", website) if property_ids.empty?

        # Count features for properties in the scope
        counts = Feature
          .where(realty_asset_id: property_ids)
          .where(feature_key: feature_keys)
          .group(:feature_key)
          .count

        build_facet_list("property-features", counts, website)
      end

      # Calculate counts for amenities (equipment & services)
      def calculate_amenities(scope, website)
        amenity_keys = FieldKey.by_tag("property-amenities").pluck(:global_key)
        return [] if amenity_keys.empty?

        # Get property IDs from the current scope
        property_ids = scope.pluck(:id)
        return build_empty_facet_list("property-amenities", website) if property_ids.empty?

        # Count amenities for properties in the scope
        counts = Feature
          .where(realty_asset_id: property_ids)
          .where(feature_key: amenity_keys)
          .group(:feature_key)
          .count

        build_facet_list("property-amenities", counts, website)
      end

      # Calculate bedroom count distribution
      def calculate_bedrooms(scope)
        counts = scope.where.not(count_bedrooms: nil)
                      .group(:count_bedrooms)
                      .count
                      .sort_by { |k, _| k.to_i }

        counts.map do |bedroom_count, property_count|
          {
            value: bedroom_count.to_s,
            label: bedroom_count.to_s,
            count: property_count
          }
        end
      end

      # Calculate bathroom count distribution
      def calculate_bathrooms(scope)
        counts = scope.where.not(count_bathrooms: nil)
                      .group(:count_bathrooms)
                      .count
                      .sort_by { |k, _| k.to_i }

        counts.map do |bathroom_count, property_count|
          {
            value: bathroom_count.to_s,
            label: bathroom_count.to_s,
            count: property_count
          }
        end
      end

      private

      # Build facet list from field keys and counts
      def build_facet_list(tag, counts, website)
        field_keys = FieldKey.by_tag(tag)
        field_keys = field_keys.where("pwb_website_id IS NULL OR pwb_website_id = ?", website.id) if website

        field_keys.visible.order(:global_key).map do |fk|
          {
            global_key: fk.global_key,
            value: fk.global_key,
            label: translate_key(fk.global_key),
            count: counts[fk.global_key] || 0
          }
        end.sort_by { |f| [-f[:count], f[:label].to_s.downcase] }
      end

      # Build empty facet list (when no properties match)
      def build_empty_facet_list(tag, website)
        field_keys = FieldKey.by_tag(tag)
        field_keys = field_keys.where("pwb_website_id IS NULL OR pwb_website_id = ?", website.id) if website

        field_keys.visible.order(:global_key).map do |fk|
          {
            global_key: fk.global_key,
            value: fk.global_key,
            label: translate_key(fk.global_key),
            count: 0
          }
        end
      end

      # Translate a field key, with fallback to humanized key name
      def translate_key(global_key)
        translation = I18n.t(global_key, default: nil)
        return translation if translation.present?

        # Fallback: humanize the last part of the key
        # e.g., "features.private_pool" -> "Private Pool"
        global_key.split('.').last.to_s.humanize.titleize
      end
    end
  end
end
