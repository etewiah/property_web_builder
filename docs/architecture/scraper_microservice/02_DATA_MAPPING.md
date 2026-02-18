# 02 — Data Mapping

## The Core Challenge

PWS returns data in its `Listing` / `PwbListing` format. PWB expects data in its `extracted_data` format (with `asset_data` and `listing_data` sub-hashes). A translation layer is needed.

## PWS Output → PWB Input Mapping

### Asset Data (Physical Property)

| PWS Field (PwbListing) | PWB Field (asset_data) | Type | Notes |
|------------------------|------------------------|------|-------|
| `reference` | `reference` | string | Direct map |
| `street_address` | `street_address` | string | Direct map |
| `street_number` | `street_number` | string | Direct map; PWB has field but import service doesn't use it separately |
| `street_name` | `street_name` | string | Direct map; same as above |
| `city` | `city` | string | Direct map |
| `province` | `region` | string | **Name differs**: PWS uses `province`, PWB uses `region` |
| `region` | `region` | string | PWS has both; prefer `region`, fall back to `province` |
| `postal_code` | `postal_code` | string | Direct map |
| `country` | `country` | string | Direct map |
| `latitude` | `latitude` | float | Direct map |
| `longitude` | `longitude` | float | Direct map |
| `count_bedrooms` | `count_bedrooms` | integer | Direct map |
| `count_bathrooms` | `count_bathrooms` | float | Direct map (PWS stores as float too) |
| `count_toilets` | `count_toilets` | integer | Direct map; PWB model has it but import service doesn't use it |
| `count_garages` | `count_garages` | integer | Direct map |
| `constructed_area` | `constructed_area` | float | Direct map |
| `plot_area` | `plot_area` | float | Direct map |
| `year_construction` | `year_construction` | integer | Direct map; PWS has it but few mappings extract it |
| `energy_rating` | `energy_rating` | string/int | Direct map |
| `energy_performance` | `energy_performance` | string/float | Direct map |
| `area_unit` | — | string | PWB doesn't store this; could be used for display or conversion |
| — | `prop_type_key` | string | **Missing from PWS**; needs new mapping or inference from `property_type` text |
| — | `prop_state_key` | string | **Missing from PWS**; default "good" is acceptable |

### Listing Data (Sale/Rental Transaction)

| PWS Field (PwbListing) | PWB Field (listing_data) | Type | Notes |
|------------------------|--------------------------|------|-------|
| `title` | `title` | string | Direct map |
| `description` | `description` | string | Direct map |
| `price_sale_current` | `price_sale_current` | float | PWS computes: `price_float` if `for_sale`, else `0` |
| `price_rental_monthly_current` | `price_rental_monthly` | float | PWS computes: `price_float` if `for_rent_long_term`, else `0` |
| `currency` | `currency` | string | Direct map |
| `for_sale` | → listing type detection | boolean | PWB uses this to decide which listing to create |
| `for_rent_long_term` | → listing type detection | boolean | Same |
| `for_rent_short_term` | → listing type detection | boolean | Same |
| `furnished` | `furnished` | boolean | Direct map |
| — | `visible` | boolean | **Not in PWS**; default `true` |
| — | `highlighted` | boolean | **Not in PWS**; default `false` |
| — | `listing_type` | string | **Not in PWS**; can be inferred from `for_sale`/`for_rent_*` booleans |

### Images

| PWS Field | PWB Field | Notes |
|-----------|-----------|-------|
| `property_photos` | `images` (array) | PWS returns `[{url: "..."}]`; PWB expects flat array of URL strings |
| `image_urls` (raw Listing) | `images` (array) | Alternative: raw Listing field is already a flat array |

### Features

| PWS Field | PWB Field | Notes |
|-----------|-----------|-------|
| `features` | — | PWB has a `features` model but `PropertyImportFromScrapeService` doesn't import them yet |

### Fields in PWS Not Used by PWB

| PWS Field | Status | Notes |
|-----------|--------|-------|
| `price_string` | Unused | Human-readable price; PWB formats from cents |
| `price_float` | Used indirectly | Via `price_sale_current` / `price_rental_monthly_current` |
| `main_image_url` | Unused | PWB uses the full `image_urls` array; first image is primary |
| `address_string` | Unused | PWB uses structured address fields |
| `for_rent` | Unused | Redundant with `for_rent_long_term` / `for_rent_short_term` |
| `locale_code` | Unused | PWB handles locales via Mobility gem separately |
| `import_url` | Unused | PWB already has this as `source_url` on `ScrapedProperty` |
| `title_es`, `description_es`, etc. | Unused | PWB handles translations differently (JSONB `translations` column) |
| `unknown_fields` | Unused | Diagnostic field |

### Fields in PWB Not Provided by PWS

| PWB Field | Resolution |
|-----------|------------|
| `prop_type_key` | **Recommend adding to PWS** — map from portal-specific types to standard enum |
| `prop_state_key` | Default to `"good"` |
| `listing_type` | Infer from `for_sale` / `for_rent_long_term` / `for_rent_short_term` booleans |

## Prop Type Key Mapping

PWB uses these standardized property types:

```
apartment, house, villa, studio, land, commercial, office, garage, storage, other
```

PWS scraper mappings extract raw `property_type` text (e.g., "Detached", "Flat", "Terraced", "Piso", "Casa"). A mapping table is needed:

| Raw Text (examples) | PWB `prop_type_key` |
|---------------------|---------------------|
| Flat, Apartment, Piso, Appartement | `apartment` |
| House, Detached, Semi-detached, Terraced, Casa, Maison | `house` |
| Villa, Chalet | `villa` |
| Studio | `studio` |
| Land, Plot, Terreno, Terrain | `land` |
| Commercial, Shop, Retail, Local | `commercial` |
| Office, Oficina, Bureau | `office` |
| Garage, Parking | `garage` |
| Storage, Trastero | `storage` |
| (anything else) | `other` |

This mapping should live in PWS so it can normalize before returning data.

## Data Transformation Code (PWB Side)

The `ExternalScraperClient` in PWB will transform PWS's response into the `extracted_data` format:

```ruby
# Pseudocode for the transformation
def transform_pws_response(pws_listing)
  {
    asset_data: {
      reference: pws_listing["reference"],
      street_address: pws_listing["street_address"],
      city: pws_listing["city"],
      region: pws_listing["region"] || pws_listing["province"],
      postal_code: pws_listing["postal_code"],
      country: pws_listing["country"],
      latitude: pws_listing["latitude"],
      longitude: pws_listing["longitude"],
      prop_type_key: pws_listing["prop_type_key"] || "other",
      count_bedrooms: pws_listing["count_bedrooms"],
      count_bathrooms: pws_listing["count_bathrooms"],
      count_garages: pws_listing["count_garages"],
      constructed_area: pws_listing["constructed_area"],
      plot_area: pws_listing["plot_area"],
      year_construction: pws_listing["year_construction"],
      energy_rating: pws_listing["energy_rating"],
      energy_performance: pws_listing["energy_performance"]
    },
    listing_data: {
      title: pws_listing["title"],
      description: pws_listing["description"],
      price_sale_current: pws_listing["price_sale_current"],
      price_rental_monthly: pws_listing["price_rental_monthly_current"],
      currency: pws_listing["currency"],
      listing_type: detect_listing_type(pws_listing),
      furnished: pws_listing["furnished"] || false,
      visible: true
    },
    images: extract_image_urls(pws_listing)
  }
end

def detect_listing_type(listing)
  return "rental" if listing["for_rent_long_term"] || listing["for_rent_short_term"]
  "sale"
end

def extract_image_urls(listing)
  photos = listing["property_photos"]
  return photos.map { |p| p["url"] } if photos.is_a?(Array)
  listing["image_urls"] || []
end
```
