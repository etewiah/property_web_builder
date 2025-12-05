-- Materialized view that denormalizes pwb_realty_assets + pwb_sale_listings + pwb_rental_listings
-- into a single queryable "property" view that matches the old pwb_props interface
-- v02: Now uses the 'active' field to select which listing to display (only one active per asset)

SELECT
  -- Primary key (from asset)
  a.id,

  -- Asset reference and basic info
  a.reference,
  a.website_id,

  -- Physical attributes (from asset)
  a.year_construction,
  a.count_bedrooms,
  a.count_bathrooms,
  a.count_toilets,
  a.count_garages,
  a.plot_area,
  a.constructed_area,
  a.energy_rating,
  a.energy_performance,

  -- Location (from asset)
  a.street_number,
  a.street_name,
  a.street_address,
  a.postal_code,
  a.city,
  a.region,
  a.country,
  a.latitude,
  a.longitude,

  -- Property classification (from asset)
  a.prop_origin_key,
  a.prop_state_key,
  a.prop_type_key,

  -- Sale listing data (only the active listing is shown)
  sl.id AS sale_listing_id,
  COALESCE(sl.visible, false) AND NOT COALESCE(sl.archived, true) AS for_sale,
  COALESCE(sl.price_sale_current_cents, 0) AS price_sale_current_cents,
  COALESCE(sl.price_sale_current_currency, 'EUR') AS price_sale_current_currency,
  COALESCE(sl.commission_cents, 0) AS commission_cents,
  COALESCE(sl.commission_currency, 'EUR') AS commission_currency,
  COALESCE(sl.reserved, false) AS sale_reserved,
  COALESCE(sl.furnished, false) AS sale_furnished,
  COALESCE(sl.highlighted, false) AS sale_highlighted,

  -- Rental listing data (only the active listing is shown)
  rl.id AS rental_listing_id,
  COALESCE(rl.visible, false) AND NOT COALESCE(rl.archived, true) AS for_rent,
  COALESCE(rl.for_rent_short_term, false) AS for_rent_short_term,
  COALESCE(rl.for_rent_long_term, false) AS for_rent_long_term,
  COALESCE(rl.price_rental_monthly_current_cents, 0) AS price_rental_monthly_current_cents,
  COALESCE(rl.price_rental_monthly_current_currency, 'EUR') AS price_rental_monthly_current_currency,
  COALESCE(rl.price_rental_monthly_low_season_cents, 0) AS price_rental_monthly_low_season_cents,
  COALESCE(rl.price_rental_monthly_high_season_cents, 0) AS price_rental_monthly_high_season_cents,
  COALESCE(rl.reserved, false) AS rental_reserved,
  COALESCE(rl.furnished, false) AS rental_furnished,
  COALESCE(rl.highlighted, false) AS rental_highlighted,

  -- Computed fields for backwards compatibility
  (COALESCE(sl.visible, false) AND NOT COALESCE(sl.archived, true))
    OR (COALESCE(rl.visible, false) AND NOT COALESCE(rl.archived, true)) AS visible,

  COALESCE(sl.highlighted, false) OR COALESCE(rl.highlighted, false) AS highlighted,

  COALESCE(sl.reserved, false) OR COALESCE(rl.reserved, false) AS reserved,

  COALESCE(sl.furnished, false) OR COALESCE(rl.furnished, false) AS furnished,

  -- For search: use rental price that makes sense for searching
  CASE
    WHEN COALESCE(rl.for_rent_short_term, false) THEN
      LEAST(
        NULLIF(COALESCE(rl.price_rental_monthly_low_season_cents, 0), 0),
        NULLIF(COALESCE(rl.price_rental_monthly_current_cents, 0), 0),
        NULLIF(COALESCE(rl.price_rental_monthly_high_season_cents, 0), 0)
      )
    ELSE
      COALESCE(rl.price_rental_monthly_current_cents, 0)
  END AS price_rental_monthly_for_search_cents,

  -- Currency (prefer sale currency, fall back to rental)
  COALESCE(sl.price_sale_current_currency, rl.price_rental_monthly_current_currency, 'EUR') AS currency,

  -- Timestamps
  a.created_at,
  a.updated_at

FROM pwb_realty_assets a
LEFT JOIN pwb_sale_listings sl
  ON sl.realty_asset_id = a.id
  AND sl.active = true
LEFT JOIN pwb_rental_listings rl
  ON rl.realty_asset_id = a.id
  AND rl.active = true
