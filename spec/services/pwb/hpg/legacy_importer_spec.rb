# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pwb::Hpg::LegacyImporter do
  let(:website) { create(:pwb_website) }
  let(:importer) { described_class.new(website) }
  let(:base_url) { 'https://hpg-scoot.homestocompare.com' }

  # --- Fixture data ---

  let(:game_slug) { 'steel-city-edition-sheffield-house-prices' }
  let(:listing_uuid) { 'f627bf16-aaaa-bbbb-cccc-111111111111' }
  let(:sale_listing_uuid) { '33f2b08a-fbe2-4a36-82e9-6cc1d1e4551f' }

  let(:available_game_details) do
    {
      'uuid' => '1347c375-ef77-496f-ba85-f2ec5b7da30e',
      'realty_game_slug' => game_slug,
      'guessed_prices_count' => 7430,
      'game_sessions_count' => 1127,
      'game_listings_count' => 11,
      'game_start_at' => '2025-07-29T12:40:13.482Z',
      'game_end_at' => '2025-08-05T13:40:13.483Z',
      'game_bg_image_url' => 'https://upload.wikimedia.org/sheffield.jpg',
      'game_title' => 'Steel City Edition: Sheffield House Prices',
      'game_description' => 'Test your knowledge of Sheffield house prices',
      'game_default_currency' => 'EUR',
      'game_default_country' => 'UK',
      'is_hidden_from_landing_page' => false
    }
  end

  let(:show_games_response) do
    {
      'scoot' => {
        'scoot_title' => '',
        'is_price_guess_enabled' => true,
        'available_games_details' => [available_game_details]
      },
      'round_up_realty_games' => []
    }
  end

  let(:listing_data) do
    {
      'id' => 10,
      'uuid' => listing_uuid,
      'source_listing_currency' => 'GBP',
      'position_in_game' => 0,
      'visible_in_game' => true,
      'guessed_prices_count' => 500,
      'gl_vicinity' => 'South Yorkshire',
      'gl_country_code' => 'England',
      'gl_image_url' => 'https://media.example.com/property1.jpg',
      'gl_title_atr' => '',
      'gl_title' => '3 bedroom terraced house',
      'gl_description' => '<p>A lovely house</p>',
      'gl_latitude' => 53.3713,
      'gl_longitude' => -1.5239,
      'gl_origin_url' => 'https://www.example.com/details/12345',
      'price_to_be_guessed_cents' => 27500000,
      'is_sale_listing_price_poll' => true,
      'listing_position_in_game' => 1,
      'listing_details' => {
        'title' => '3 bedroom terraced house',
        'uuid' => sale_listing_uuid,
        'listing_title' => '3 bedroom terraced house',
        'listing_count_bedrooms' => 3,
        'listing_count_bathrooms' => 1.0,
        'listing_count_garages' => 1,
        'listing_city' => 'Sheffield',
        'listing_street_address' => 'Fulwood Road, Sheffield S10',
        'listing_postal_code' => 'S10 3QA',
        'country_code' => 'ENGLAND'
      }
    }
  end

  let(:game_summary_response) do
    {
      'realty_game_details' => {
        'game_global_slug' => game_slug,
        'game_title' => 'Steel City Edition: Sheffield House Prices',
        'game_description' => 'Test your knowledge of Sheffield house prices',
        'game_bg_image_url' => 'https://upload.wikimedia.org/sheffield.jpg',
        'default_game_currency' => 'EUR',
        'game_start_at' => '2025-07-29T12:40:13.482Z',
        'game_end_at' => '2025-08-05T13:40:13.483Z',
        'uuid' => '1347c375-ef77-496f-ba85-f2ec5b7da30e'
      },
      'price_guess_inputs' => {
        'game_listings' => [listing_data],
        'guessed_price_validation' => {
          'max_percentage_above' => 900,
          'min_percentage_below' => 90,
          'messages' => {
            'too_high' => 'Guess is way way too high',
            'too_low' => 'Guess is way too low',
            'positive_number' => 'Please enter a positive number'
          }
        }
      }
    }
  end

  let(:show_rgl_response) do
    {
      'realty_game_listing' => {
        'uuid' => listing_uuid,
        'game_listing_pics' => [
          {
            'id' => 1498,
            'uuid' => '8ca3237f-892e-4471-8aea-87a9938d1928',
            'photo_title' => nil,
            'photo_description' => 'Front view',
            'sort_order' => 1,
            'photo_slug' => 'https://media.example.com/property1.jpg',
            'image_details' => {
              'url' => 'https://media.example.com/property1-full.jpg'
            }
          },
          {
            'id' => 1499,
            'uuid' => 'aabbccdd-1111-2222-3333-444444444444',
            'photo_title' => nil,
            'photo_description' => 'Garden',
            'sort_order' => 2,
            'photo_slug' => 'https://media.example.com/property1-garden.jpg',
            'image_details' => {
              'url' => 'https://media.example.com/property1-garden-full.jpg'
            }
          }
        ]
      },
      'sale_listing' => {
        'uuid' => sale_listing_uuid,
        'title' => '3 bedroom terraced house for sale',
        'city' => 'Sheffield',
        'street_address' => 'Fulwood Road, Sheffield S10',
        'postal_code' => 'S10 3QA',
        'country' => 'England',
        'latitude' => 53.3713269,
        'longitude' => -1.5238709,
        'count_bedrooms' => 3,
        'count_bathrooms' => 1.0,
        'price_sale_current_cents' => 27500000,
        'price_sale_current_currency' => 'GBP',
        'sale_listing_pics' => []
      }
    }
  end

  # --- Stub helpers ---

  def stub_show_games(scoot_slug = 'hpg-scoot')
    stub_request(:get, "#{base_url}/api_public/v4/scoots/show_games/#{scoot_slug}")
      .to_return(status: 200, body: show_games_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_game_summary(slug = game_slug)
    stub_request(:get, "#{base_url}/api_public/v4/realty_game_summary/#{slug}")
      .to_return(status: 200, body: game_summary_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_show_rgl(uuid = listing_uuid)
    stub_request(:get, "#{base_url}/api_public/v4/game_sale_listings/show_rgl/#{uuid}")
      .to_return(status: 200, body: show_rgl_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_all_endpoints
    stub_show_games
    stub_game_summary
    stub_show_rgl
  end

  # --- Tests ---

  describe '#initialize' do
    it 'sets the website and initializes stats' do
      expect(importer.website).to eq(website)
      expect(importer.stats).to eq({ games: 0, assets: 0, listings: 0, photos: 0, errors: [] })
    end
  end

  describe '#import_all_games' do
    before { stub_all_endpoints }

    it 'fetches the games list and imports each game' do
      importer.import_all_games('hpg-scoot')

      expect(Pwb::RealtyGame.count).to eq(1)
      expect(Pwb::RealtyAsset.count).to eq(1)
      expect(Pwb::GameListing.count).to eq(1)
    end

    it 'creates the game with correct attributes' do
      importer.import_all_games('hpg-scoot')

      game = Pwb::RealtyGame.first
      expect(game.slug).to eq(game_slug)
      expect(game.title).to eq('Steel City Edition: Sheffield House Prices')
      expect(game.description).to eq('Test your knowledge of Sheffield house prices')
      expect(game.default_currency).to eq('EUR')
      expect(game.active).to be true
      expect(game.sessions_count).to eq(1127)
      expect(game.estimates_count).to eq(7430)
      expect(game.hidden_from_landing_page).to be false
      expect(game.website).to eq(website)
    end

    it 'stores validation rules from the game summary' do
      importer.import_all_games('hpg-scoot')

      game = Pwb::RealtyGame.first
      expect(game.validation_rules).to include(
        'max_percentage_above' => 900,
        'min_percentage_below' => 90
      )
      expect(game.validation_rules['messages']).to include(
        'too_high' => 'Guess is way way too high'
      )
    end

    it 'creates the realty asset with correct property data' do
      importer.import_all_games('hpg-scoot')

      asset = Pwb::RealtyAsset.first
      expect(asset.street_address).to eq('Fulwood Road, Sheffield S10')
      expect(asset.city).to eq('Sheffield')
      expect(asset.country).to eq('England')
      expect(asset.postal_code).to eq('S10 3QA')
      expect(asset.count_bedrooms).to eq(3)
      expect(asset.count_bathrooms).to eq(1.0)
      expect(asset.count_garages).to eq(1)
      expect(asset.latitude).to eq(53.3713)
      expect(asset.longitude).to eq(-1.5239)
      expect(asset.website).to eq(website)
    end

    it 'creates a sale listing with the correct price' do
      importer.import_all_games('hpg-scoot')

      asset = Pwb::RealtyAsset.first
      sale_listing = asset.sale_listings.first
      expect(sale_listing).to be_present
      expect(sale_listing.price_sale_current_cents).to eq(27500000)
      expect(sale_listing.price_sale_current_currency).to eq('GBP')
      expect(sale_listing.visible).to be true
      expect(sale_listing.active).to be true
    end

    it 'creates the game listing with correct attributes' do
      importer.import_all_games('hpg-scoot')

      gl = Pwb::GameListing.first
      expect(gl.sort_order).to eq(1) # listing_position_in_game
      expect(gl.visible).to be true
      expect(gl.display_title).to eq('3 bedroom terraced house')
      expect(gl.extra_data['legacy_listing_uuid']).to eq(listing_uuid)
      expect(gl.extra_data['gl_origin_url']).to eq('https://www.example.com/details/12345')
      expect(gl.extra_data['price_to_be_guessed_cents']).to eq(27500000)
    end

    it 'creates photos from the listing detail endpoint' do
      importer.import_all_games('hpg-scoot')

      asset = Pwb::RealtyAsset.first
      photos = asset.prop_photos.order(:sort_order)
      # gl_image_url photo + 2 from show_rgl (one may share same URL as gl_image_url)
      expect(photos.count).to be >= 2
      urls = photos.pluck(:external_url)
      expect(urls).to include('https://media.example.com/property1.jpg')
      expect(urls).to include('https://media.example.com/property1-garden-full.jpg')
    end

    it 'reports correct stats' do
      importer.import_all_games('hpg-scoot')

      expect(importer.stats[:games]).to eq(1)
      expect(importer.stats[:assets]).to eq(1)
      expect(importer.stats[:listings]).to eq(1)
      expect(importer.stats[:errors]).to be_empty
    end

    context 'with multiple games' do
      let(:second_game_slug) { 'fox-city-edition-leicester-house-prices' }
      let(:second_listing_uuid) { 'dddddddd-eeee-ffff-0000-222222222222' }

      let(:show_games_response) do
        {
          'scoot' => {
            'available_games_details' => [
              available_game_details,
              available_game_details.merge(
                'realty_game_slug' => second_game_slug,
                'game_title' => 'Fox City Edition',
                'game_sessions_count' => 385
              )
            ]
          },
          'round_up_realty_games' => []
        }
      end

      let(:second_game_summary) do
        game_summary_response.deep_dup.tap do |s|
          s['realty_game_details']['game_global_slug'] = second_game_slug
          s['realty_game_details']['game_title'] = 'Fox City Edition'
          gl = s['price_guess_inputs']['game_listings'][0]
          gl['uuid'] = second_listing_uuid
          gl['gl_title'] = '2 bedroom flat'
          gl['listing_details']['listing_title'] = '2 bedroom flat'
          gl['listing_details']['listing_city'] = 'Leicester'
        end
      end

      let(:second_show_rgl) do
        show_rgl_response.deep_dup.tap do |s|
          s['realty_game_listing']['uuid'] = second_listing_uuid
          s['realty_game_listing']['game_listing_pics'] = []
          s['sale_listing']['city'] = 'Leicester'
        end
      end

      before do
        stub_show_games
        stub_game_summary
        stub_show_rgl

        stub_request(:get, "#{base_url}/api_public/v4/realty_game_summary/#{second_game_slug}")
          .to_return(status: 200, body: second_game_summary.to_json, headers: { 'Content-Type' => 'application/json' })
        stub_request(:get, "#{base_url}/api_public/v4/game_sale_listings/show_rgl/#{second_listing_uuid}")
          .to_return(status: 200, body: second_show_rgl.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'imports all games' do
        importer.import_all_games('hpg-scoot')

        expect(Pwb::RealtyGame.count).to eq(2)
        expect(importer.stats[:games]).to eq(2)
        slugs = Pwb::RealtyGame.pluck(:slug)
        expect(slugs).to contain_exactly(game_slug, second_game_slug)
      end
    end
  end

  describe '#import_game' do
    before do
      stub_game_summary
      stub_show_rgl
    end

    it 'imports a single game by slug' do
      importer.import_game(game_slug)

      expect(Pwb::RealtyGame.count).to eq(1)
      expect(Pwb::RealtyGame.first.slug).to eq(game_slug)
    end

    it 'creates assets and listings for the game' do
      importer.import_game(game_slug)

      expect(Pwb::RealtyAsset.count).to eq(1)
      expect(Pwb::SaleListing.count).to eq(1)
      expect(Pwb::GameListing.count).to eq(1)
    end
  end

  describe 'idempotency' do
    before { stub_all_endpoints }

    it 'does not create duplicate games on re-run' do
      importer.import_all_games('hpg-scoot')
      expect(Pwb::RealtyGame.count).to eq(1)

      # Run again
      fresh_importer = described_class.new(website)
      fresh_importer.import_all_games('hpg-scoot')
      expect(Pwb::RealtyGame.count).to eq(1)
    end

    it 'does not create duplicate game listings on re-run' do
      importer.import_all_games('hpg-scoot')
      expect(Pwb::GameListing.count).to eq(1)

      fresh_importer = described_class.new(website)
      fresh_importer.import_all_games('hpg-scoot')
      expect(Pwb::GameListing.count).to eq(1)
    end

    it 'does not create duplicate sale listings on re-run' do
      importer.import_all_games('hpg-scoot')
      expect(Pwb::SaleListing.count).to eq(1)

      fresh_importer = described_class.new(website)
      fresh_importer.import_all_games('hpg-scoot')
      expect(Pwb::SaleListing.count).to eq(1)
    end

    it 'does not create duplicate photos on re-run' do
      importer.import_all_games('hpg-scoot')
      photo_count = Pwb::PropPhoto.count

      fresh_importer = described_class.new(website)
      fresh_importer.import_all_games('hpg-scoot')
      expect(Pwb::PropPhoto.count).to eq(photo_count)
    end
  end

  describe 'error handling' do
    it 'continues to next game when one game fails' do
      second_slug = 'fox-city-edition-leicester-house-prices'

      show_games_with_two = {
        'scoot' => {
          'available_games_details' => [
            available_game_details,
            available_game_details.merge('realty_game_slug' => second_slug)
          ]
        },
        'round_up_realty_games' => []
      }

      stub_request(:get, "#{base_url}/api_public/v4/scoots/show_games/hpg-scoot")
        .to_return(status: 200, body: show_games_with_two.to_json, headers: { 'Content-Type' => 'application/json' })

      # First game fails
      stub_request(:get, "#{base_url}/api_public/v4/realty_game_summary/#{game_slug}")
        .to_return(status: 500, body: 'Internal Server Error')

      # Second game succeeds
      stub_request(:get, "#{base_url}/api_public/v4/realty_game_summary/#{second_slug}")
        .to_return(status: 200, body: game_summary_response.deep_dup.tap { |s|
          s['realty_game_details']['game_global_slug'] = second_slug
          s['realty_game_details']['game_title'] = 'Fox City Edition'
        }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_show_rgl

      importer.import_all_games('hpg-scoot')

      expect(Pwb::RealtyGame.count).to eq(1)
      expect(Pwb::RealtyGame.first.slug).to eq(second_slug)
      expect(importer.stats[:errors].size).to eq(1)
      expect(importer.stats[:errors].first).to include(game_slug)
    end

    it 'handles photo fetch failures gracefully' do
      stub_show_games
      stub_game_summary

      # Photo fetch returns 404
      stub_request(:get, "#{base_url}/api_public/v4/game_sale_listings/show_rgl/#{listing_uuid}")
        .to_return(status: 404, body: 'Not Found')

      importer.import_all_games('hpg-scoot')

      # Game and asset should still be created
      expect(Pwb::RealtyGame.count).to eq(1)
      expect(Pwb::RealtyAsset.count).to eq(1)
      # gl_image_url photo should still exist
      expect(Pwb::PropPhoto.count).to eq(1)
    end
  end

  describe 'game listing extra_data' do
    before { stub_all_endpoints }

    it 'stores legacy metadata in extra_data JSONB' do
      importer.import_all_games('hpg-scoot')

      gl = Pwb::GameListing.first
      expect(gl.extra_data).to include(
        'legacy_listing_uuid' => listing_uuid,
        'legacy_game_listing_id' => 10,
        'gl_origin_url' => 'https://www.example.com/details/12345',
        'gl_vicinity' => 'South Yorkshire',
        'gl_country_code' => 'England',
        'source_listing_currency' => 'GBP',
        'guessed_prices_count' => 500,
        'is_sale_listing_price_poll' => true,
        'price_to_be_guessed_cents' => 27500000
      )
    end
  end

  describe 'game start/end times' do
    before { stub_all_endpoints }

    it 'parses ISO8601 timestamps' do
      importer.import_all_games('hpg-scoot')

      game = Pwb::RealtyGame.first
      expect(game.start_at).to be_present
      expect(game.end_at).to be_present
      expect(game.start_at.year).to eq(2025)
    end
  end

  describe 'asset enrichment from sale_listing data' do
    before { stub_all_endpoints }

    context 'when listing_details has blank city' do
      let(:listing_data) do
        super().tap do |d|
          d['listing_details']['listing_city'] = nil
        end
      end

      it 'falls back to gl_vicinity for city' do
        importer.import_all_games('hpg-scoot')

        asset = Pwb::RealtyAsset.first
        expect(asset.city).to eq('South Yorkshire')
      end
    end

    context 'when listing_details and gl_vicinity are both blank' do
      let(:listing_data) do
        super().tap do |d|
          d['listing_details']['listing_city'] = nil
          d['gl_vicinity'] = nil
        end
      end

      it 'enriches city from sale_listing endpoint data' do
        importer.import_all_games('hpg-scoot')

        asset = Pwb::RealtyAsset.first
        expect(asset.city).to eq('Sheffield')
      end
    end
  end

  describe 'hidden game listing' do
    before do
      modified_summary = game_summary_response.deep_dup
      modified_summary['price_guess_inputs']['game_listings'][0]['visible_in_game'] = false

      stub_show_games
      stub_request(:get, "#{base_url}/api_public/v4/realty_game_summary/#{game_slug}")
        .to_return(status: 200, body: modified_summary.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_show_rgl
    end

    it 'sets visible to false on the game listing' do
      importer.import_all_games('hpg-scoot')

      gl = Pwb::GameListing.first
      expect(gl.visible).to be false
    end
  end

  describe 'display_title fallback' do
    before { stub_all_endpoints }

    context 'when gl_title_atr is empty' do
      it 'uses gl_title as display_title' do
        importer.import_all_games('hpg-scoot')

        gl = Pwb::GameListing.first
        expect(gl.display_title).to eq('3 bedroom terraced house')
      end
    end

    context 'when gl_title_atr is present' do
      let(:listing_data) do
        super().tap { |d| d['gl_title_atr'] = 'Custom Title Override' }
      end

      it 'uses gl_title_atr as display_title' do
        importer.import_all_games('hpg-scoot')

        gl = Pwb::GameListing.first
        expect(gl.display_title).to eq('Custom Title Override')
      end
    end
  end
end
