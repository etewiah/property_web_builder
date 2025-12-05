# frozen_string_literal: true

namespace :field_keys do
  desc "Migrate Spanish field keys to English with new categorization"
  task migrate_to_english: :environment do
    # Complete mapping from Spanish keys to new English structure
    MAPPINGS = {
      # ============================================
      # Property Types (property-types)
      # ============================================
      'propertyTypes.apartamento' => { key: 'types.apartment', tag: 'property-types' },
      'propertyTypes.chaletIndependiente' => { key: 'types.house', tag: 'property-types' },
      'propertyTypes.bungalow' => { key: 'types.bungalow', tag: 'property-types' },
      'propertyTypes.inversion' => { key: 'types.investment', tag: 'property-types' },
      'propertyTypes.solar' => { key: 'types.land', tag: 'property-types' },
      'propertyTypes.piso' => { key: 'types.apartment', tag: 'property-types' }, # Same as apartamento
      'propertyTypes.hotel' => { key: 'types.hotel', tag: 'property-types' },
      'propertyTypes.chaletAdosado' => { key: 'types.townhouse', tag: 'property-types' },
      'propertyTypes.atico' => { key: 'types.penthouse', tag: 'property-types' },
      'propertyTypes.estudio' => { key: 'types.studio', tag: 'property-types' },
      'propertyTypes.garaje' => { key: 'types.garage', tag: 'property-types' },
      'propertyTypes.local' => { key: 'types.commercial', tag: 'property-types' },
      'propertyTypes.trastero' => { key: 'types.storage', tag: 'property-types' },
      'propertyTypes.villa' => { key: 'types.villa', tag: 'property-types' },
      'propertyTypes.casaRural' => { key: 'types.farmhouse', tag: 'property-types' },
      'propertyTypes.edificioResidencial' => { key: 'types.residential_building', tag: 'property-types' },

      # ============================================
      # Property States (property-states)
      # ============================================
      'propertyStates.enConstruccion' => { key: 'states.under_construction', tag: 'property-states' },
      'propertyStates.nuevo' => { key: 'states.new_build', tag: 'property-states' },
      'propertyStates.aReformar' => { key: 'states.needs_renovation', tag: 'property-states' },
      'propertyStates.segundaMano' => { key: 'states.good_condition', tag: 'property-states' },

      # ============================================
      # Property Features (property-features) - Permanent physical attributes
      # ============================================
      'extras.balcon' => { key: 'features.balcony', tag: 'property-features' },
      'extras.terraza' => { key: 'features.terrace', tag: 'property-features' },
      'extras.porche' => { key: 'features.porch', tag: 'property-features' },
      'extras.patioInterior' => { key: 'features.patio', tag: 'property-features' },
      'extras.jardinPrivado' => { key: 'features.private_garden', tag: 'property-features' },
      'extras.jardinComunitario' => { key: 'features.community_garden', tag: 'property-features' },
      'extras.piscinaPrivada' => { key: 'features.private_pool', tag: 'property-features' },
      'extras.piscinaComunitaria' => { key: 'features.community_pool', tag: 'property-features' },
      'extras.piscinaClimatizada' => { key: 'features.heated_pool', tag: 'property-features' },
      'extras.garajePrivado' => { key: 'features.private_garage', tag: 'property-features' },
      'extras.garajeComunitario' => { key: 'features.community_garage', tag: 'property-features' },
      'extras.trastero' => { key: 'features.storage', tag: 'property-features' },
      'extras.lavadero' => { key: 'features.laundry_room', tag: 'property-features' },
      'extras.cocinaIndependiente' => { key: 'features.separate_kitchen', tag: 'property-features' },
      'extras.chimenea' => { key: 'features.fireplace', tag: 'property-features' },
      'extras.jacuzzi' => { key: 'features.jacuzzi', tag: 'property-features' },
      'extras.sauna' => { key: 'features.sauna', tag: 'property-features' },
      'extras.solarium' => { key: 'features.solarium', tag: 'property-features' },
      'extras.barbacoa' => { key: 'features.barbecue', tag: 'property-features' },
      'extras.vistasAlMar' => { key: 'features.sea_views', tag: 'property-features' },
      'extras.vistasALaMontana' => { key: 'features.mountain_views', tag: 'property-features' },
      'extras.zonaDeportiva' => { key: 'features.sports_area', tag: 'property-features' },
      'extras.zonasInfantiles' => { key: 'features.play_area', tag: 'property-features' },
      'extras.parquet' => { key: 'features.wooden_floor', tag: 'property-features' },
      'extras.sueloMarmol' => { key: 'features.marble_floor', tag: 'property-features' },

      # ============================================
      # Property Amenities (property-amenities) - Equipment & services
      # ============================================
      'extras.aireAcondicionado' => { key: 'amenities.air_conditioning', tag: 'property-amenities' },
      'extras.calefaccionCentral' => { key: 'amenities.central_heating', tag: 'property-amenities' },
      'extras.calefaccionElectrica' => { key: 'amenities.electric_heating', tag: 'property-amenities' },
      'extras.calefaccionGasCiudad' => { key: 'amenities.gas_heating', tag: 'property-amenities' },
      'extras.calefaccionGasoleo' => { key: 'amenities.oil_heating', tag: 'property-amenities' },
      'extras.calefaccionPropano' => { key: 'amenities.propane_heating', tag: 'property-amenities' },
      'extras.energiaSolar' => { key: 'amenities.solar_energy', tag: 'property-amenities' },
      'extras.alarma' => { key: 'amenities.alarm', tag: 'property-amenities' },
      'extras.vigilancia' => { key: 'amenities.security', tag: 'property-amenities' },
      'extras.videoportero' => { key: 'amenities.video_intercom', tag: 'property-amenities' },
      'extras.servPorteria' => { key: 'amenities.concierge', tag: 'property-amenities' },
      'extras.ascensor' => { key: 'amenities.elevator', tag: 'property-amenities' },
      'extras.amueblado' => { key: 'amenities.furnished', tag: 'property-amenities' },
      'extras.semiamueblado' => { key: 'amenities.semi_furnished', tag: 'property-amenities' },
      'extras.nevera' => { key: 'amenities.refrigerator', tag: 'property-amenities' },
      'extras.horno' => { key: 'amenities.oven', tag: 'property-amenities' },
      'extras.microondas' => { key: 'amenities.microwave', tag: 'property-amenities' },
      'extras.lavadora' => { key: 'amenities.washing_machine', tag: 'property-amenities' },
      'extras.tv' => { key: 'amenities.tv', tag: 'property-amenities' },

      # ============================================
      # Property Status (property-status) - Transaction status
      # ============================================
      'propertyLabels.sold' => { key: 'status.sold', tag: 'property-status' },
      'propertyLabels.reserved' => { key: 'status.reserved', tag: 'property-status' },
      'propertyLabels.ee' => { key: 'highlights.energy_efficient', tag: 'property-highlights' },

      # ============================================
      # Listing Origin (listing-origin)
      # ============================================
      'propertyOrigin.bank' => { key: 'origin.bank', tag: 'listing-origin' },
      'propertyOrigin.new' => { key: 'origin.new_construction', tag: 'listing-origin' },
      'propertyOrigin.private' => { key: 'origin.private', tag: 'listing-origin' },

      # ============================================
      # Person Titles (unchanged - not property related)
      # ============================================
      # 'personTitles.mr' is not a property field key, skip it
    }.freeze

    puts "Starting field key migration from Spanish to English..."
    puts "=" * 60

    migrated_count = 0
    skipped_count = 0
    errors = []

    ActiveRecord::Base.transaction do
      MAPPINGS.each do |old_key, new_values|
        new_key = new_values[:key]
        new_tag = new_values[:tag]

        # Skip if duplicate mapping (e.g., piso -> apartment when apartamento already mapped)
        if Pwb::FieldKey.exists?(global_key: new_key)
          puts "  [SKIP] #{old_key} -> #{new_key} (target already exists)"
          skipped_count += 1

          # Still update references to point to the existing key
          update_references(old_key, new_key)
          next
        end

        # Find and update the FieldKey
        field_key = Pwb::FieldKey.find_by(global_key: old_key)
        if field_key
          begin
            field_key.update!(global_key: new_key, tag: new_tag)
            puts "  [OK] FieldKey: #{old_key} -> #{new_key} (#{new_tag})"
            migrated_count += 1
          rescue => e
            errors << "FieldKey #{old_key}: #{e.message}"
            puts "  [ERROR] FieldKey: #{old_key} - #{e.message}"
          end
        else
          puts "  [SKIP] FieldKey not found: #{old_key}"
        end

        # Update references in other tables
        # Update Features
        feature_count = Pwb::Feature.where(feature_key: old_key).update_all(feature_key: new_key)
        puts "    - Updated #{feature_count} features" if feature_count > 0

        # Update RealtyAssets prop_type_key
        type_count = Pwb::RealtyAsset.where(prop_type_key: old_key).update_all(prop_type_key: new_key)
        puts "    - Updated #{type_count} realty_asset prop_type_key" if type_count > 0

        # Update RealtyAssets prop_state_key
        state_count = Pwb::RealtyAsset.where(prop_state_key: old_key).update_all(prop_state_key: new_key)
        puts "    - Updated #{state_count} realty_asset prop_state_key" if state_count > 0

        # Update RealtyAssets prop_origin_key
        origin_count = Pwb::RealtyAsset.where(prop_origin_key: old_key).update_all(prop_origin_key: new_key)
        puts "    - Updated #{origin_count} realty_asset prop_origin_key" if origin_count > 0
      end

      # Refresh materialized view after all changes
      puts "\nRefreshing materialized view..."
      Pwb::ListedProperty.refresh
      puts "  [OK] Materialized view refreshed"
    end

    puts "\n" + "=" * 60
    puts "Migration complete!"
    puts "  Migrated: #{migrated_count}"
    puts "  Skipped:  #{skipped_count}"
    puts "  Errors:   #{errors.count}"

    if errors.any?
      puts "\nErrors:"
      errors.each { |e| puts "  - #{e}" }
    end
  end

  desc "List all current field keys with their tags"
  task list: :environment do
    puts "Current Field Keys:"
    puts "=" * 60

    Pwb::FieldKey.order(:tag, :global_key).each do |fk|
      puts "  #{fk.tag.ljust(20)} | #{fk.global_key}"
    end

    puts "\nTotal: #{Pwb::FieldKey.count} keys"
  end

  desc "Create missing field keys with English structure"
  task seed_english: :environment do
    puts "Seeding missing English field keys..."

    # Additional keys that may not exist yet
    NEW_KEYS = {
      'property-types' => [
        'types.apartment', 'types.house', 'types.villa', 'types.bungalow',
        'types.penthouse', 'types.duplex', 'types.studio', 'types.townhouse',
        'types.farmhouse', 'types.cottage', 'types.land', 'types.commercial',
        'types.office', 'types.warehouse', 'types.retail', 'types.garage'
      ],
      'property-states' => [
        'states.new_build', 'states.under_construction', 'states.good_condition',
        'states.needs_renovation', 'states.renovated', 'states.to_demolish'
      ],
      'property-status' => [
        'status.available', 'status.reserved', 'status.under_offer',
        'status.sold', 'status.rented', 'status.off_market'
      ],
      'property-highlights' => [
        'highlights.featured', 'highlights.new_listing', 'highlights.price_reduced',
        'highlights.exclusive', 'highlights.luxury', 'highlights.investment',
        'highlights.energy_efficient'
      ],
      'listing-origin' => [
        'origin.direct', 'origin.import', 'origin.mls', 'origin.api', 'origin.partner'
      ]
    }.freeze

    created_count = 0

    NEW_KEYS.each do |tag, keys|
      keys.each do |global_key|
        unless Pwb::FieldKey.exists?(global_key: global_key)
          Pwb::FieldKey.create!(global_key: global_key, tag: tag, visible: true)
          puts "  [CREATED] #{global_key} (#{tag})"
          created_count += 1
        end
      end
    end

    puts "\nCreated #{created_count} new field keys"
  end
end
