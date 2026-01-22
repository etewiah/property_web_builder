# frozen_string_literal: true

module ApiPublic
  module V1
    # SearchConfigController provides filter configuration for headless frontend search pages
    # Returns property types, price options, features, and sort options
    class SearchConfigController < BaseController
      include ApiPublic::Cacheable

      # GET /api_public/v1/search/config
      def index
        website = Pwb::Current.website
        locale = params[:locale] || I18n.locale
        I18n.locale = locale

        # Cache search config for 30 minutes - changes occasionally
        etag_data = [website.id, website.updated_at, locale]
        set_long_cache(max_age: 30.minutes, etag_data: etag_data)
        return if performed?

        render json: {
          property_types: property_types_with_counts(website),
          price_options: {
            sale: {
              from: website.sale_price_options_from,
              to: website.sale_price_options_till
            },
            rent: {
              from: website.rent_price_options_from,
              to: website.rent_price_options_till
            }
          },
          features: available_features(website),
          bedrooms: (0..10).to_a,
          bathrooms: (0..6).to_a,
          sort_options: [
            { value: 'price_asc', label: I18n.t('search.sort.price_asc', default: 'Price: Low to High') },
            { value: 'price_desc', label: I18n.t('search.sort.price_desc', default: 'Price: High to Low') },
            { value: 'newest', label: I18n.t('search.sort.newest', default: 'Newest First') },
            { value: 'bedrooms_desc', label: I18n.t('search.sort.bedrooms_desc', default: 'Most Bedrooms') }
          ],
          area_unit: website.default_area_unit || 'sqm',
          currency: website.default_currency || 'EUR'
        }
      end

      private

      def property_types_with_counts(website)
        counts = website.listed_properties
                        .visible
                        .group(:prop_type_key)
                        .count

        counts.map do |key, count|
          next if key.blank?

          {
            key: key.to_s.split('.').last,
            label: I18n.t("propertyTypes.#{key.to_s.split('.').last}", default: key.to_s.split('.').last.titleize),
            count: count
          }
        end.compact
      end

      def available_features(website)
        # Get features from FieldKeys if available
        feature_keys = PwbTenant::FieldKey.where(website: website, tag: 'feature')

        if feature_keys.any?
          feature_keys.map do |fk|
            {
              key: fk.field_key_tag,
              label: fk.label.presence || I18n.t("features.#{fk.field_key_tag}", default: fk.field_key_tag.titleize)
            }
          end
        else
          # Fallback: extract unique feature keys from existing listings
          feature_keys = PwbTenant::Feature.joins(:realty_asset)
                                           .where(pwb_realty_assets: { website_id: website.id })
                                           .distinct
                                           .limit(50)
                                           .pluck(:feature_key)

          feature_keys.compact.uniq.first(20).map do |feature_key|
            {
              key: feature_key.to_s,
              label: feature_key.to_s.split('.').last&.titleize
            }
          end
        end
      rescue StandardError => e
        Rails.logger.warn("[SearchConfig] Error loading features: #{e.message}")
        []
      end
    end
  end
end
