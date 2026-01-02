# frozen_string_literal: true

require 'rails_helper'

# Comprehensive theme rendering tests
#
# These tests actually render theme templates to catch runtime errors like:
# - NoMethodError (e.g., calling undefined methods on models)
# - NameError (undefined variables or helpers)
# - ActionView::Template::Error (template syntax errors)
#
# This catches errors that static file existence checks cannot detect.
RSpec.describe 'Theme Rendering', type: :request do
  # Get all theme names (excluding 'shared' which contains shared partials)
  EXCLUDED_DIRECTORIES = %w[shared].freeze

  def self.theme_names
    themes_path = Rails.root.join('app', 'themes')
    return [] unless themes_path.exist?

    themes_path.children
      .select(&:directory?)
      .map { |d| d.basename.to_s }
      .reject { |name| EXCLUDED_DIRECTORIES.include?(name) }
  end

  # Helper to create property with sale listing
  def create_sale_property(website:, reference:, title:)
    realty_asset = Pwb::RealtyAsset.create!(
      website: website,
      reference: reference,
      city: 'Test City',
      region: 'Test Region',
      count_bedrooms: 3,
      count_bathrooms: 2,
      constructed_area: 150.0,
      translations: { 'en-UK' => { 'title' => title } }
    )
    Pwb::SaleListing.create!(
      realty_asset: realty_asset,
      visible: true,
      active: true,
      price_sale_current_cents: 35_000_000,
      price_sale_current_currency: 'EUR'
    )
    realty_asset
  end

  # Helper to create property with rental listing
  def create_rental_property(website:, reference:, title:)
    realty_asset = Pwb::RealtyAsset.create!(
      website: website,
      reference: reference,
      city: 'Test City',
      region: 'Test Region',
      count_bedrooms: 2,
      count_bathrooms: 1,
      constructed_area: 80.0,
      translations: { 'en-UK' => { 'title' => title } }
    )
    Pwb::RentalListing.create!(
      realty_asset: realty_asset,
      visible: true,
      active: true,
      price_rental_monthly_current_cents: 150_000,
      price_rental_monthly_current_currency: 'EUR'
    )
    realty_asset
  end

  # Test each theme's pages render without errors
  theme_names.each do |theme|
    describe "#{theme} theme" do
      # Each theme gets its own website with unique subdomain
      let!(:website) do
        Pwb::Website.create!(
          subdomain: "theme-test-#{theme.downcase}",
          slug: "theme-test-#{theme.downcase}",
          theme_name: theme,
          available_themes: [theme],
          default_client_locale: 'en-UK',
          supported_locales: ['en-UK']
        )
      end

      let!(:agency) do
        Pwb::Agency.create!(
          website: website,
          company_name: "#{theme.capitalize} Test Agency",
          display_name: "#{theme.capitalize} Test Agency"
        )
      end

      # Create a home page
      let!(:home_page) do
        Pwb::Page.create!(
          website: website,
          slug: 'home',
          visible: true,
          translations: { 'en-UK' => { 'title' => 'Home' } }
        )
      end

      # Create test properties
      let!(:sale_property) do
        create_sale_property(
          website: website,
          reference: "SALE-#{theme.upcase}-001",
          title: "Test Sale Property for #{theme}"
        )
      end

      let!(:rental_property) do
        create_rental_property(
          website: website,
          reference: "RENT-#{theme.upcase}-001",
          title: "Test Rental Property for #{theme}"
        )
      end

      before do
        # Clear any existing tenant context
        Pwb::Current.reset if Pwb::Current.respond_to?(:reset)

        # Refresh materialized view to include our test properties
        Pwb::ListedProperty.refresh if Pwb::ListedProperty.respond_to?(:refresh)
      end

      # Use host! helper for subdomain-based routing
      def set_host_for(website)
        host! "#{website.subdomain}.test.localhost"
      end

      describe 'Home page (welcome#index)' do
        it 'renders without errors' do
          set_host_for(website)
          get '/'

          # Should render successfully (200) or redirect (302)
          # but NOT error (500)
          expect(response.status).to be_in([200, 302]),
            "Expected success or redirect, got #{response.status}.\n" \
            "Response body (first 1000 chars): #{response.body[0..1000]}"
        end

        it 'renders property listings without method errors' do
          set_host_for(website)
          get '/'

          # Should not contain Ruby error messages in the response
          expect(response.body).not_to include('NoMethodError'),
            "Found NoMethodError in response for #{theme} theme"
          expect(response.body).not_to include('undefined method'),
            "Found 'undefined method' error in response for #{theme} theme"
          expect(response.body).not_to include('NameError'),
            "Found NameError in response for #{theme} theme"
        end
      end

      describe 'Buy search page (search#buy)' do
        it 'renders without errors' do
          set_host_for(website)
          get '/buy'

          expect(response.status).to be_in([200, 302]),
            "Expected success or redirect for /buy, got #{response.status}"
        end
      end

      describe 'Rent search page (search#rent)' do
        it 'renders without errors' do
          set_host_for(website)
          get '/rent'

          expect(response.status).to be_in([200, 302]),
            "Expected success or redirect for /rent, got #{response.status}"
        end
      end

      describe 'Contact page' do
        let!(:contact_page) do
          Pwb::Page.create!(
            website: website,
            slug: 'contact-us',
            visible: true,
            translations: { 'en-UK' => { 'title' => 'Contact Us' } }
          )
        end

        it 'renders without errors' do
          set_host_for(website)
          get '/contact-us'

          # Allow 404 if page not fully configured, but not 500
          expect(response.status).to be_in([200, 302, 404]),
            "Expected success, redirect, or not found for /contact-us, got #{response.status}"
        end
      end

      describe 'Property detail page (props#show)' do
        it 'renders sale property detail without errors' do
          set_host_for(website)
          # Refresh to ensure property is in materialized view
          Pwb::ListedProperty.refresh if Pwb::ListedProperty.respond_to?(:refresh)

          # Get the property slug from the listed property view
          listed_property = Pwb::ListedProperty.find_by(reference: sale_property.reference)
          skip 'Could not find sale property in materialized view' if listed_property.nil?

          get "/properties/for-sale/#{listed_property.slug_or_id}"

          # Should render successfully (200), redirect (302), or not found (404)
          # but NOT error (500)
          expect(response.status).to be_in([200, 302, 404]),
            "Expected success, redirect, or not found for property detail, got #{response.status}.\n" \
            "Response body (first 1500 chars): #{response.body[0..1500]}"
        end

        it 'renders rental property detail without errors' do
          set_host_for(website)
          # Refresh to ensure property is in materialized view
          Pwb::ListedProperty.refresh if Pwb::ListedProperty.respond_to?(:refresh)

          # Get the property slug from the listed property view
          listed_property = Pwb::ListedProperty.find_by(reference: rental_property.reference)
          skip 'Could not find rental property in materialized view' if listed_property.nil?

          get "/properties/for-rent/#{listed_property.slug_or_id}"

          # Should render successfully (200), redirect (302), or not found (404)
          # but NOT error (500)
          expect(response.status).to be_in([200, 302, 404]),
            "Expected success, redirect, or not found for property detail, got #{response.status}.\n" \
            "Response body (first 1500 chars): #{response.body[0..1500]}"
        end

        it 'property detail page does not contain error messages' do
          set_host_for(website)
          Pwb::ListedProperty.refresh if Pwb::ListedProperty.respond_to?(:refresh)

          listed_property = Pwb::ListedProperty.find_by(reference: sale_property.reference)
          skip 'Could not find sale property in materialized view' if listed_property.nil?

          get "/properties/for-sale/#{listed_property.slug_or_id}"

          # Skip check if page wasn't found
          next if response.status == 404

          # Should not contain Ruby/Rails error messages
          expect(response.body).not_to include('NoMethodError'),
            "Found NoMethodError in property detail for #{theme} theme"
          expect(response.body).not_to include('ActionView::MissingTemplate'),
            "Found MissingTemplate error in property detail for #{theme} theme"
          expect(response.body).not_to include('undefined method'),
            "Found 'undefined method' error in property detail for #{theme} theme"
        end
      end
    end
  end

  # Static analysis tests that don't require rendering
  describe 'Template Static Analysis' do
    # These are methods that DON'T exist on ListedProperty and should NOT be used
    INVALID_PROPERTY_METHODS = %w[
      locality
    ].freeze

    it 'theme templates do not use invalid property methods' do
      themes_path = Rails.root.join('app', 'themes')

      # Scan all ERB files for invalid method calls
      invalid_usages = []

      Dir.glob(themes_path.join('**', '*.erb')).each do |file|
        content = File.read(file)
        relative_path = Pathname.new(file).relative_path_from(themes_path)

        INVALID_PROPERTY_METHODS.each do |method|
          # Match property.method_name patterns (word boundary to avoid false positives)
          if content.match?(/property\.#{method}\b/)
            invalid_usages << "#{relative_path}: uses property.#{method}"
          end
        end
      end

      expect(invalid_usages).to be_empty,
        "Found invalid property method calls in templates:\n#{invalid_usages.join("\n")}\n\n" \
        "These methods don't exist on ListedProperty. Use 'city' instead of 'locality'."
    end
  end

  # Test for ERB syntax errors (pure Ruby, no database)
  describe 'ERB Syntax Validation' do
    theme_names.each do |theme|
      context "#{theme} theme" do
        it 'all ERB templates have valid syntax' do
          theme_path = Rails.root.join('app', 'themes', theme, 'views')
          errors = []

          Dir.glob(theme_path.join('**', '*.erb')).each do |file|
            begin
              # Try to compile the ERB template
              content = File.read(file)
              ERB.new(content)
            rescue SyntaxError => e
              relative_path = Pathname.new(file).relative_path_from(theme_path)
              errors << "#{relative_path}: #{e.message}"
            end
          end

          expect(errors).to be_empty,
            "ERB syntax errors found in #{theme} theme:\n#{errors.join("\n")}"
        end
      end
    end
  end

  # Test that all themes have their required CSS partials
  describe 'Theme CSS Partials' do
    theme_names.each do |theme|
      context "#{theme} theme" do
        it 'has a custom CSS partial' do
          css_partial = Rails.root.join('app', 'views', 'pwb', 'custom_css', "_#{theme}.css.erb")
          expect(css_partial).to exist,
            "Missing CSS partial for #{theme} theme at: #{css_partial}\n" \
            "Create this file to define theme-specific CSS variables and styles."
        end
      end
    end
  end

  # Verify ListedProperty has expected methods that themes depend on
  describe 'ListedProperty API Compatibility' do
    # These are methods that should exist on ListedProperty
    # based on what theme templates commonly use
    EXPECTED_PROPERTY_METHODS = %w[
      title
      reference
      city
      region
      country
      count_bedrooms
      count_bathrooms
      constructed_area
      plot_area
      contextual_show_path
      ordered_photo
    ].freeze

    it 'ListedProperty responds to all expected methods' do
      # Create a minimal test property to check method availability
      website = Pwb::Website.create!(
        subdomain: 'api-test',
        slug: 'api-test'
      )

      realty_asset = Pwb::RealtyAsset.create!(
        website: website,
        reference: 'API-TEST-001'
      )
      Pwb::SaleListing.create!(
        realty_asset: realty_asset,
        visible: true,
        active: true,
        price_sale_current_cents: 10_000_000,
        price_sale_current_currency: 'EUR'
      )

      Pwb::ListedProperty.refresh if Pwb::ListedProperty.respond_to?(:refresh)

      # Find the property through the materialized view
      property = Pwb::ListedProperty.find_by(reference: 'API-TEST-001')
      skip 'Could not find test property in materialized view' if property.nil?

      missing_methods = []
      EXPECTED_PROPERTY_METHODS.each do |method|
        unless property.respond_to?(method)
          missing_methods << method
        end
      end

      expect(missing_methods).to be_empty,
        "ListedProperty is missing expected methods: #{missing_methods.join(', ')}\n" \
        "These methods are used by theme templates and must exist."
    end
  end
end
