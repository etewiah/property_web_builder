namespace :pwb do
  desc "Migrate pwb_props to normalized tables"
  task migrate_props: :environment do
    puts "Starting migration..."
    
    Pwb::Prop.find_each do |prop|
      ActiveRecord::Base.transaction do
        # 1. Create Realty Asset (Physical Attributes)
        asset = Pwb::RealtyAsset.create!(
          reference: prop.reference,
          year_construction: prop.year_construction,
          count_bedrooms: prop.count_bedrooms,
          count_bathrooms: prop.count_bathrooms,
          count_toilets: prop.count_toilets,
          count_garages: prop.count_garages,
          plot_area: prop.plot_area,
          constructed_area: prop.constructed_area,
          energy_rating: prop.energy_rating,
          energy_performance: prop.energy_performance,
          street_number: prop.street_number,
          street_name: prop.street_name,
          street_address: prop.street_address,
          postal_code: prop.postal_code,
          city: prop.city,
          region: prop.region,
          country: prop.country,
          latitude: prop.latitude,
          longitude: prop.longitude,
          prop_origin_key: prop.prop_origin_key,
          prop_state_key: prop.prop_state_key,
          prop_type_key: prop.prop_type_key,
          website_id: prop.website_id
        )

        # 2. Create Sale Listing (if applicable)
        if prop.for_sale
          Pwb::SaleListing.create!(
            realty_asset: asset,
            reference: "#{prop.reference}-SALE",
            visible: prop.visible,
            highlighted: prop.highlighted,
            archived: prop.archived,
            reserved: prop.reserved,
            furnished: prop.furnished,
            price_sale_current_cents: prop.price_sale_current_cents,
            price_sale_current_currency: prop.price_sale_current_currency,
            commission_cents: prop.commission_cents,
            commission_currency: prop.commission_currency
          )
        end

        # 3. Create Rental Listing (if applicable)
        if prop.for_rent_short_term || prop.for_rent_long_term
          Pwb::RentalListing.create!(
            realty_asset: asset,
            reference: "#{prop.reference}-RENT",
            visible: prop.visible,
            highlighted: prop.highlighted,
            archived: prop.archived,
            reserved: prop.reserved,
            furnished: prop.furnished,
            for_rent_short_term: prop.for_rent_short_term,
            for_rent_long_term: prop.for_rent_long_term,
            price_rental_monthly_current_cents: prop.price_rental_monthly_current_cents,
            price_rental_monthly_current_currency: prop.price_rental_monthly_current_currency,
            price_rental_monthly_low_season_cents: prop.price_rental_monthly_low_season_cents,
            price_rental_monthly_high_season_cents: prop.price_rental_monthly_high_season_cents
          )
        end
      end
    end
    puts "Migration complete. Processed #{Pwb::Prop.count} properties."
  end
end
