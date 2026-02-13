# frozen_string_literal: true

require 'net/http'
require 'json'

module Pwb
  module Hpg
    # Imports games and listings from the legacy HPG backend into PWB models.
    #
    # The legacy backend at hpg-scoot.homestocompare.com exposes:
    #   GET /api_public/v4/scoots/show_games/:scoot_slug  — all games + scoot metadata
    #   GET /api_public/v4/realty_game_summary/:game_slug  — single game with listings
    #   GET /api_public/v4/game_sale_listings/show_rgl/:uuid — individual listing with photos
    #
    # Usage:
    #   importer = Pwb::Hpg::LegacyImporter.new(website)
    #   importer.import_all_games("hpg-scoot")
    #   importer.import_game("hpg-scoot", "steel-city-edition-sheffield-house-prices")
    #
    class LegacyImporter
      BASE_URL = ENV.fetch('HPG_LEGACY_API_BASE', 'https://hpg-scoot.homestocompare.com')

      attr_reader :website, :stats

      def initialize(website)
        @website = website
        @stats = { games: 0, assets: 0, listings: 0, photos: 0, errors: [] }
      end

      # Import all games from the legacy scoot endpoint
      def import_all_games(scoot_slug)
        puts "Fetching games list from #{BASE_URL}..."
        data = fetch_json("/api_public/v4/scoots/show_games/#{scoot_slug}")

        scoot = data['scoot']
        available_games = scoot&.dig('available_games_details') || []
        puts "Found #{available_games.size} games to import."

        available_games.each do |game_summary|
          slug = game_summary['realty_game_slug']
          begin
            import_single_game(slug, game_summary)
          rescue StandardError => e
            msg = "Error importing game '#{slug}': #{e.message}"
            puts "  ERROR: #{msg}"
            @stats[:errors] << msg
          end
        end

        print_stats
      end

      # Import a single game by slug
      def import_game(slug)
        import_single_game(slug)
        print_stats
      end

      private

      def import_single_game(slug, available_game_details = nil)
        puts "\nImporting game: #{slug}..."

        summary = fetch_json("/api_public/v4/realty_game_summary/#{slug}")
        game_details = summary['realty_game_details']
        price_inputs = summary['price_guess_inputs']
        game_listings_data = price_inputs&.dig('game_listings') || []

        game = find_or_create_game(slug, game_details, price_inputs, available_game_details)
        puts "  Game: #{game.title} (#{game.slug})"

        game_listings_data.each_with_index do |gl_data, idx|
          begin
            import_listing(game, gl_data, idx)
          rescue StandardError => e
            msg = "Error importing listing #{idx} for game '#{slug}': #{e.message}"
            puts "    ERROR: #{msg}"
            @stats[:errors] << msg
          end
        end

        @stats[:games] += 1
      end

      def find_or_create_game(request_slug, game_details, price_inputs, available_game_details)
        # game_global_slug is sometimes empty; fall back to game_default_locale or the slug we fetched with
        slug = game_details['game_global_slug'].presence ||
               game_details['game_default_locale'].presence ||
               request_slug
        validation_rules = price_inputs&.dig('guessed_price_validation') || {}

        # Merge session/estimate counts from available_games_details if present
        sessions_count = available_game_details&.dig('game_sessions_count') || 0
        estimates_count = available_game_details&.dig('guessed_prices_count') || 0
        hidden = available_game_details&.dig('is_hidden_from_landing_page') || false
        default_country = available_game_details&.dig('game_default_country')

        game = website.realty_games.find_or_initialize_by(slug: slug)
        game.assign_attributes(
          title: game_details['game_title'],
          description: game_details['game_description'],
          bg_image_url: game_details['game_bg_image_url'],
          default_currency: game_details['default_game_currency'] || 'EUR',
          default_country: default_country,
          start_at: parse_time(game_details['game_start_at']),
          end_at: parse_time(game_details['game_end_at']),
          validation_rules: validation_rules,
          sessions_count: sessions_count,
          estimates_count: estimates_count,
          hidden_from_landing_page: hidden,
          active: true
        )
        game.save!
        game
      end

      def import_listing(game, gl_data, index)
        legacy_uuid = gl_data['uuid']
        listing_details = gl_data['listing_details'] || {}

        # Create or find the RealtyAsset (physical property)
        asset = find_or_create_asset(gl_data, listing_details, legacy_uuid)

        # Create or find the SaleListing (price data)
        find_or_create_sale_listing(asset, gl_data)

        # Create the photo from gl_image_url
        create_photo_from_gl(asset, gl_data)

        # Fetch individual listing for additional photos
        fetch_and_create_photos(asset, legacy_uuid)

        # Create the GameListing (join record)
        find_or_create_game_listing(game, asset, gl_data, legacy_uuid, index)

        puts "    Listing #{index + 1}: #{gl_data['gl_title'] || listing_details['listing_title'] || 'untitled'}"
      end

      def find_or_create_asset(gl_data, listing_details, legacy_uuid)
        # Use legacy UUID stored in extra_data to find existing assets
        existing_gl = Pwb::GameListing.where("extra_data->>'legacy_listing_uuid' = ?", legacy_uuid).first
        if existing_gl
          @stats[:assets] += 0 # not new
          return existing_gl.realty_asset
        end

        # Build asset attributes from the legacy data
        title = listing_details['listing_title'] || gl_data['gl_title']
        street_address = listing_details['listing_street_address'] || ''
        city = listing_details['listing_city'] || extract_city_from_sale_listing(gl_data)
        country = gl_data['gl_country_code'].presence || listing_details['country_code']
        postal_code = listing_details['listing_postal_code']
        latitude = parse_float(gl_data['gl_latitude'])
        longitude = parse_float(gl_data['gl_longitude'])
        bedrooms = listing_details['listing_count_bedrooms'] || 0
        bathrooms = listing_details['listing_count_bathrooms'] || 0
        garages = listing_details['listing_count_garages'] || 0

        asset = Pwb::RealtyAsset.new(
          website: website,
          street_address: street_address,
          city: city,
          country: country,
          postal_code: postal_code,
          latitude: latitude,
          longitude: longitude,
          count_bedrooms: bedrooms.to_i,
          count_bathrooms: bathrooms.to_f,
          count_garages: garages.to_i,
          reference: "HPG-#{legacy_uuid[0..7]}"
        )
        # Write title to the DB column directly (RealtyAsset overrides title method to return nil)
        asset.write_attribute(:title, title)
        asset.save!
        @stats[:assets] += 1
        asset
      end

      def find_or_create_sale_listing(asset, gl_data)
        price_cents = gl_data['price_to_be_guessed_cents'] || 0
        currency = gl_data['source_listing_currency'] || 'EUR'

        # Only create if no active sale listing exists for this asset
        existing = asset.sale_listings.active_listing.first
        return existing if existing

        listing = asset.sale_listings.create!(
          price_sale_current_cents: price_cents,
          price_sale_current_currency: currency,
          visible: true,
          active: true
        )
        @stats[:listings] += 1
        listing
      end

      def create_photo_from_gl(asset, gl_data)
        image_url = gl_data['gl_image_url']
        return unless image_url.present?

        # Skip if photo with this URL already exists
        return if asset.prop_photos.exists?(external_url: image_url)

        asset.prop_photos.create!(
          external_url: image_url,
          sort_order: 0
        )
        @stats[:photos] += 1
      end

      def fetch_and_create_photos(asset, legacy_uuid)
        data = fetch_json("/api_public/v4/game_sale_listings/show_rgl/#{legacy_uuid}")
        rgl = data['realty_game_listing'] || {}
        pics = rgl['game_listing_pics'] || []

        # Also check sale_listing pics
        sale_listing = data['sale_listing'] || {}
        sale_pics = sale_listing['sale_listing_pics'] || []

        all_pics = (pics + sale_pics).uniq { |p| p['uuid'] }

        all_pics.each_with_index do |pic, idx|
          url = pic.dig('image_details', 'url') || pic['photo_slug']
          next unless url.present?
          next if asset.prop_photos.exists?(external_url: url)

          asset.prop_photos.create!(
            external_url: url,
            description: pic['photo_description'],
            sort_order: pic['sort_order'] || (idx + 1)
          )
          @stats[:photos] += 1
        end

        # Also update asset with fuller sale_listing data if available
        update_asset_from_sale_listing(asset, sale_listing)
      rescue StandardError => e
        # Non-critical: photo fetch failure shouldn't stop the import
        puts "    Warning: Could not fetch photos for #{legacy_uuid}: #{e.message}"
      end

      def update_asset_from_sale_listing(asset, sale_listing_data)
        return if sale_listing_data.empty?

        updates = {}
        updates[:city] = sale_listing_data['city'] if sale_listing_data['city'].present? && asset.city.blank?
        updates[:street_address] = sale_listing_data['street_address'] if sale_listing_data['street_address'].present? && asset.street_address.blank?
        updates[:postal_code] = sale_listing_data['postal_code'] if sale_listing_data['postal_code'].present? && asset.postal_code.blank?
        updates[:region] = sale_listing_data['region'] if sale_listing_data['region'].present? && asset.region.blank?
        updates[:country] = sale_listing_data['country'] if sale_listing_data['country'].present? && asset.country.blank?
        updates[:latitude] = sale_listing_data['latitude'].to_f if sale_listing_data['latitude'].present? && asset.latitude.blank?
        updates[:longitude] = sale_listing_data['longitude'].to_f if sale_listing_data['longitude'].present? && asset.longitude.blank?
        updates[:count_bedrooms] = sale_listing_data['count_bedrooms'].to_i if sale_listing_data['count_bedrooms'].present? && asset.count_bedrooms == 0
        updates[:count_bathrooms] = sale_listing_data['count_bathrooms'].to_f if sale_listing_data['count_bathrooms'].present? && asset.count_bathrooms == 0.0

        asset.update!(updates) if updates.any?
      end

      def find_or_create_game_listing(game, asset, gl_data, legacy_uuid, index)
        existing = game.game_listings.find_by(realty_asset: asset)
        return existing if existing

        extra_data = {
          'legacy_listing_uuid' => legacy_uuid,
          'legacy_game_listing_id' => gl_data['id'],
          'gl_origin_url' => gl_data['gl_origin_url'],
          'gl_vicinity' => gl_data['gl_vicinity'],
          'gl_country_code' => gl_data['gl_country_code'],
          'source_listing_currency' => gl_data['source_listing_currency'],
          'guessed_prices_count' => gl_data['guessed_prices_count'],
          'is_sale_listing_price_poll' => gl_data['is_sale_listing_price_poll'],
          'price_to_be_guessed_cents' => gl_data['price_to_be_guessed_cents']
        }

        display_title = gl_data['gl_title_atr'].presence || gl_data['gl_title']
        sort_order = gl_data['listing_position_in_game'] || gl_data['position_in_game'] || index

        game.game_listings.create!(
          realty_asset: asset,
          sort_order: sort_order.to_i,
          visible: gl_data['visible_in_game'] != false,
          display_title: display_title,
          extra_data: extra_data
        )
      end

      # HTTP helpers

      def fetch_json(path)
        uri = URI("#{BASE_URL}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          # Disable CRL checking which some legacy servers don't support
          http.verify_callback = ->(_preverify_ok, store_ctx) {
            # Accept the cert if the only error is CRL-related
            err = store_ctx.error
            err == 0 || err == OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL
          }
        end

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "HTTP #{response.code} for #{path}: #{response.body&.truncate(200)}"
        end

        JSON.parse(response.body)
      end

      # Utility helpers

      def parse_time(value)
        return nil if value.blank?
        Time.parse(value)
      rescue ArgumentError
        nil
      end

      def parse_float(value)
        return nil if value.blank?
        float = value.to_f
        float == 0.0 ? nil : float
      end

      def extract_city_from_sale_listing(gl_data)
        # The listing_details sometimes has city info, fall back to vicinity
        gl_data['gl_vicinity'].presence
      end

      def print_stats
        puts "\n=== Import Summary ==="
        puts "  Games imported: #{@stats[:games]}"
        puts "  Assets created: #{@stats[:assets]}"
        puts "  Sale listings created: #{@stats[:listings]}"
        puts "  Photos created: #{@stats[:photos]}"
        if @stats[:errors].any?
          puts "  Errors (#{@stats[:errors].size}):"
          @stats[:errors].each { |e| puts "    - #{e}" }
        else
          puts "  Errors: none"
        end
        puts "======================"
      end
    end
  end
end
