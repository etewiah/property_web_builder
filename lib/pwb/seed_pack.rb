# frozen_string_literal: true

require_relative 'seed_images'

# Seed Pack System for PropertyWebBuilder
#
# Seed Packs are pre-configured bundles of seed data representing real-world
# scenarios. Each pack contains all the data needed to create a fully functional
# tenant website for a specific use case.
#
# Usage:
#   pack = Pwb::SeedPack.find('spain_luxury')
#   pack.apply!(website: website)
#
# See docs/architecture/seed_packs_plan.md for full documentation.
#
module Pwb
  class SeedPack
    class PackNotFoundError < StandardError; end
    class InvalidPackError < StandardError; end

    PACKS_PATH = Rails.root.join('db', 'seeds', 'packs')

    attr_reader :name, :config, :path

    # Convenience accessors for common config values
    def display_name
      config[:display_name] || name.titleize
    end

    def description
      config[:description]
    end

    def version
      config[:version] || '1.0'
    end

    def initialize(name)
      @name = name.to_s
      @path = PACKS_PATH.join(@name)
      validate_pack_exists!
      @config = load_config
    end

    # Apply this seed pack to a website
    #
    # @param website [Pwb::Website] The website to seed
    # @param options [Hash] Options for seeding
    # @option options [Boolean] :skip_website Skip website configuration
    # @option options [Boolean] :skip_agency Skip agency seeding
    # @option options [Boolean] :skip_properties Skip property seeding
    # @option options [Boolean] :skip_users Skip user seeding
    # @option options [Boolean] :skip_content Skip content seeding
    # @option options [Boolean] :skip_translations Skip translation seeding
    # @option options [Boolean] :dry_run Preview changes without applying
    # @option options [Boolean] :verbose Show detailed output (default: true)
    #
    def apply!(website:, options: {})
      @website = website
      @options = default_options.merge(options)
      @verbose = @options.fetch(:verbose, true)

      validate!

      log "Applying seed pack '#{name}' to website '#{website.subdomain}'...", :info

      if @options[:dry_run]
        log "DRY RUN MODE - No changes will be made", :warning
        return preview
      end

      # Apply inherited pack first
      apply_parent_pack! if config[:inherits_from]

      # Apply this pack's data in order
      seed_website unless @options[:skip_website]
      seed_agency unless @options[:skip_agency]
      seed_field_keys unless @options[:skip_field_keys]
      seed_links unless @options[:skip_links]
      seed_pages unless @options[:skip_pages]
      seed_page_parts unless @options[:skip_page_parts]
      seed_properties unless @options[:skip_properties]
      seed_content unless @options[:skip_content]
      seed_users unless @options[:skip_users]
      seed_translations unless @options[:skip_translations]

      # Refresh materialized view
      log "Refreshing properties materialized view...", :info
      Pwb::ListedProperty.refresh rescue nil

      log "Seed pack '#{name}' applied successfully!", :success
      true
    end

    # Returns a preview of what would be created
    def preview
      {
        pack_name: name,
        display_name: config[:display_name],
        inherits_from: config[:inherits_from],
        website: config[:website],
        agency: config[:agency],
        properties: property_files.count,
        locales: config.dig(:website, :supported_locales) || [],
        users: users_config.count
      }
    end

    # List all available seed packs
    def self.available
      return [] unless PACKS_PATH.exist?

      PACKS_PATH.children.select(&:directory?).filter_map do |dir|
        pack_file = dir.join('pack.yml')
        next unless pack_file.exist?

        begin
          new(dir.basename.to_s)
        rescue StandardError
          nil
        end
      end
    end

    # Find a pack by name
    def self.find(name)
      new(name)
    end

    private

    def default_options
      {
        skip_website: false,
        skip_agency: false,
        skip_properties: false,
        skip_users: false,
        skip_content: false,
        skip_translations: false,
        skip_field_keys: false,
        skip_links: false,
        skip_pages: false,
        skip_page_parts: false,
        dry_run: false,
        verbose: true
      }
    end

    def validate_pack_exists!
      unless @path.exist?
        available = self.class.available.map { |p| p[:name] }.join(', ')
        raise PackNotFoundError, "Seed pack '#{@name}' not found at #{@path}. Available packs: #{available}"
      end

      pack_file = @path.join('pack.yml')
      unless pack_file.exist?
        raise InvalidPackError, "Seed pack '#{@name}' is missing pack.yml configuration"
      end
    end

    def load_config
      pack_file = @path.join('pack.yml')
      config = YAML.safe_load(File.read(pack_file), permitted_classes: [Symbol], symbolize_names: true) || {}
      config[:name] ||= @name
      config
    end

    def validate!
      errors = []
      errors << "Missing 'display_name'" unless config[:display_name]
      errors << "Missing 'website' configuration" unless config[:website]

      if errors.any?
        raise InvalidPackError, "Seed pack '#{name}' is invalid: #{errors.join(', ')}"
      end
    end

    def apply_parent_pack!
      parent_name = config[:inherits_from]
      log "Applying parent pack '#{parent_name}'...", :info

      parent = self.class.find(parent_name)
      parent.apply!(
        website: @website,
        options: @options.merge(
          skip_website: true,  # Don't override website config from parent
          skip_agency: true,   # Don't override agency from parent
          verbose: false       # Reduce noise from parent
        )
      )
    end

    # ============================================
    # Seeding Methods
    # ============================================

    def seed_website
      log "Configuring website...", :info

      website_config = config[:website] || {}

      @website.update!(
        theme_name: website_config[:theme_name] || 'bristol',
        default_client_locale: website_config[:default_client_locale] || 'en',
        default_area_unit: website_config[:area_unit] || 'sqm',
        default_currency: website_config[:currency] || 'EUR'
      )

      log "  Website configured: theme=#{@website.theme_name}, locale=#{@website.default_client_locale}", :detail
    end

    def seed_agency
      log "Seeding agency...", :info

      agency_config = config[:agency] || {}
      return unless agency_config.any?

      agency = @website.agency || @website.build_agency
      agency.assign_attributes(
        display_name: agency_config[:display_name],
        email_primary: agency_config[:email],
        phone_number_primary: agency_config[:phone]
      )
      agency.save!

      # Seed agency address if provided
      if agency_config[:address]
        addr = agency_config[:address]
        address = agency.primary_address || Pwb::Address.new
        address.assign_attributes(
          city: addr[:city],
          region: addr[:region],
          country: addr[:country],
          postal_code: addr[:postal_code],
          street_address: addr[:street_address]
        )
        address.save!
        agency.update!(primary_address: address) unless agency.primary_address_id == address.id
      end

      log "  Agency: #{agency.display_name}", :detail
    end

    def seed_field_keys
      field_keys_file = @path.join('field_keys.yml')
      return unless field_keys_file.exist?

      log "Seeding field keys...", :info

      data = YAML.safe_load(File.read(field_keys_file), symbolize_names: true) || {}
      count = 0

      # Handle both legacy list format and new nested hash format
      if data.is_a?(Array)
        data.each do |fk|
          existing = Pwb::FieldKey.find_by(global_key: fk[:global_key] || fk[:field_key], pwb_website_id: @website.id)
          unless existing
            # Handle legacy key name
            fk[:global_key] ||= fk.delete(:field_key)
            Pwb::FieldKey.create!(fk.merge(pwb_website_id: @website.id))
            count += 1
          end
        end
      elsif data.is_a?(Hash)
        # Map YAML categories to DB tags
        category_map = {
          types: 'property-types',
          states: 'property-states',
          features: 'property-features',
          amenities: 'property-amenities',
          extras: 'property-features'
        }

        data.each do |category, keys|
          tag = category_map[category] || "property-#{category}"
          
          keys.each do |key_name, translations|
            # Create FieldKey record
            existing = Pwb::FieldKey.find_by(global_key: key_name.to_s, pwb_website_id: @website.id)
            unless existing
              Pwb::FieldKey.create!(
                global_key: key_name.to_s,
                tag: tag,
                pwb_website_id: @website.id,
                visible: true
              )
              count += 1
            end
          end
        end
      end

      log "  Created #{count} field keys", :detail
    end

    def seed_links
      links_file = @path.join('links.yml')
      return unless links_file.exist?

      log "Seeding navigation links...", :info

      links = YAML.safe_load(File.read(links_file), symbolize_names: true) || []
      count = 0

      links.each do |link_data|
        existing = @website.links.find_by(slug: link_data[:slug])
        unless existing
          @website.links.create!(link_data)
          count += 1
        end
      end

      log "  Created #{count} links", :detail
    end

    def seed_pages
      pages_dir = @path.join('pages')
      return unless pages_dir.exist?

      log "Seeding pages...", :info

      count = 0
      Dir.glob(pages_dir.join('*.yml')).each do |page_file|
        page_data = YAML.safe_load(File.read(page_file), symbolize_names: true)
        next unless page_data

        existing = @website.pages.find_by(slug: page_data[:slug])
        unless existing
          @website.pages.create!(page_data)
          count += 1
        end
      end

      log "  Created #{count} pages", :detail
    end

    def seed_page_parts
      page_parts_dir = @path.join('page_parts')

      # If the pack has page_parts configured in pack.yml or directory, use those
      if page_parts_dir.exist?
        seed_pack_page_parts(page_parts_dir)
      elsif config[:page_parts]
        seed_configured_page_parts
      else
        # Fall back to default page parts from yml_seeds
        seed_default_page_parts
      end
    end

    def seed_pack_page_parts(page_parts_dir)
      log "Seeding custom page parts from pack...", :info

      count = 0
      Dir.glob(page_parts_dir.join('*.yml')).each do |page_part_file|
        page_part_data = YAML.safe_load(File.read(page_part_file), symbolize_names: true)
        next unless page_part_data

        Array(page_part_data).each do |attrs|
          existing = Pwb::PagePart.find_by(
            page_part_key: attrs[:page_part_key],
            page_slug: attrs[:page_slug],
            website_id: @website.id
          )

          unless existing
            Pwb::PagePart.create!(attrs.merge(website_id: @website.id))
            count += 1
          end
        end
      end

      log "  Created #{count} page parts", :detail
    end

    def seed_configured_page_parts
      log "Seeding page parts from pack config...", :info

      count = 0
      config[:page_parts].each do |page_slug, parts|
        Array(parts).each do |part_config|
          # part_config can be a string (just the key) or a hash with more options
          part_key = part_config.is_a?(Hash) ? part_config[:key] : part_config.to_s

          existing = Pwb::PagePart.find_by(
            page_part_key: part_key,
            page_slug: page_slug.to_s,
            website_id: @website.id
          )

          unless existing
            # Look up editor_setup from the default page parts
            default_setup = load_default_page_part_setup(page_slug, part_key)

            attrs = {
              page_part_key: part_key,
              page_slug: page_slug.to_s,
              website_id: @website.id,
              block_contents: {},
              order_in_editor: part_config.is_a?(Hash) ? (part_config[:order] || 1) : 1,
              show_in_editor: true,
              editor_setup: default_setup || {}
            }

            Pwb::PagePart.create!(attrs)
            count += 1
          end
        end
      end

      log "  Created #{count} page parts", :detail
    end

    def seed_default_page_parts
      log "Seeding default page parts...", :info

      # Use the PagesSeeder to seed default page parts
      Pwb::PagesSeeder.seed_page_parts!(website: @website)

      log "  Default page parts seeded", :detail
    end

    def load_default_page_part_setup(page_slug, part_key)
      # Convert part_key format (e.g., "heroes/hero_centered") to filename
      filename = "#{page_slug}__#{part_key.gsub('/', '_')}.yml"
      seed_file = Rails.root.join('db', 'yml_seeds', 'page_parts', filename)

      return nil unless seed_file.exist?

      yml_contents = YAML.safe_load(File.read(seed_file), symbolize_names: true)
      yml_contents&.first&.dig(:editor_setup)
    end

    def seed_properties
      log "Seeding properties...", :info

      properties = load_properties
      return log("  No properties found", :detail) if properties.empty?

      count = 0
      properties.each do |prop_data|
        next if property_exists?(prop_data[:reference])

        create_property(prop_data)
        count += 1
      end

      log "  Created #{count} properties", :detail
    end

    def seed_content
      content_dir = @path.join('content')
      return unless content_dir.exist?

      log "Seeding content...", :info

      count = 0
      Dir.glob(content_dir.join('*.yml')).each do |content_file|
        content_data = YAML.safe_load(File.read(content_file), symbolize_names: true)
        next unless content_data

        content_data.each do |key, translations|
          content = @website.contents.find_or_initialize_by(key: key.to_s)
          translations.each do |locale, value|
            content.send("raw_#{locale}=", value) if content.respond_to?("raw_#{locale}=")
          end
          content.save!
          count += 1
        end
      end

      log "  Created/updated #{count} content items", :detail
    end

    def seed_users
      log "Seeding users...", :info

      users = users_config
      return log("  No users configured", :detail) if users.empty?

      count = 0
      users.each do |user_data|
        existing = Pwb::User.find_by(email: user_data[:email])
        user = if existing
                 existing
               else
                 new_user = Pwb::User.new(
                   email: user_data[:email],
                   password: user_data[:password] || 'password123',
                   password_confirmation: user_data[:password] || 'password123',
                   website_id: @website.id,
                   admin: user_data[:role] == 'admin'
                 )
                 new_user.save!
                 count += 1
                 new_user
               end

        # Create membership for the user based on role
        role = user_data[:role] || 'member'
        membership_role = case role
                          when 'admin', 'owner' then role
                          when 'agent' then 'member'
                          else 'member'
                          end

        Pwb::UserMembership.find_or_create_by!(user: user, website: @website) do |m|
          m.role = membership_role
          m.active = true
        end
      end

      log "  Created #{count} users", :detail
    end

    def seed_translations
      translations_dir = @path.join('translations')
      return unless translations_dir.exist?

      log "Seeding translations...", :info

      count = 0
      Dir.glob(translations_dir.join('*.yml')).each do |trans_file|
        locale = File.basename(trans_file, '.yml')
        translations = YAML.safe_load(File.read(trans_file), symbolize_names: true) || {}

        translations.each do |key, value|
          next unless value.is_a?(String)

          existing = I18n::Backend::ActiveRecord::Translation.find_by(locale: locale, key: key.to_s)
          unless existing
            I18n::Backend::ActiveRecord::Translation.create!(
              locale: locale,
              key: key.to_s,
              value: value
            )
            count += 1
          end
        end
      end

      log "  Created #{count} translations", :detail
    end

    # ============================================
    # Property Helpers
    # ============================================

    def load_properties
      properties = []

      # Load from properties directory
      properties_dir = @path.join('properties')
      if properties_dir.exist?
        Dir.glob(properties_dir.join('*.yml')).each do |prop_file|
          prop_data = YAML.safe_load(File.read(prop_file), symbolize_names: true)
          properties << prop_data if prop_data
        end
      end

      properties
    end

    def property_files
      properties_dir = @path.join('properties')
      return [] unless properties_dir.exist?
      Dir.glob(properties_dir.join('*.yml'))
    end

    def property_exists?(reference)
      Pwb::RealtyAsset.exists?(website_id: @website.id, reference: reference)
    end

    def create_property(data)
      asset = Pwb::RealtyAsset.create!(
        website_id: @website.id,
        reference: data[:reference],
        prop_type_key: data[:prop_type],
        prop_state_key: data[:prop_state] || 'states.good',
        street_address: data[:address],
        city: data[:city],
        region: data[:region],
        country: data[:country],
        postal_code: data[:postal_code],
        count_bedrooms: data[:bedrooms],
        count_bathrooms: data[:bathrooms],
        count_garages: data[:garages],
        constructed_area: data[:constructed_area],
        plot_area: data[:plot_area],
        year_construction: data[:year_built],
        latitude: data[:latitude],
        longitude: data[:longitude]
      )

      # Create sale listing if configured
      if data[:sale]
        listing = Pwb::SaleListing.create!(
          realty_asset: asset,
          visible: true,
          active: true,
          highlighted: data[:sale][:highlighted] || false,
          price_sale_current_cents: data[:sale][:price_cents],
          price_sale_current_currency: config.dig(:website, :currency) || 'EUR'
        )
        # Set translations
        (config.dig(:website, :supported_locales) || ['en']).each do |locale|
          title = data[:sale].dig(:title, locale.to_sym) || data[:sale][:title]
          desc = data[:sale].dig(:description, locale.to_sym) || data[:sale][:description]
          listing.send("title_#{locale}=", title) if title && listing.respond_to?("title_#{locale}=")
          listing.send("description_#{locale}=", desc) if desc && listing.respond_to?("description_#{locale}=")
        end
        listing.save!
      end

      # Create rental listing if configured
      if data[:rental]
        listing = Pwb::RentalListing.create!(
          realty_asset: asset,
          visible: true,
          active: true,
          highlighted: data[:rental][:highlighted] || false,
          for_rent_long_term: data[:rental][:long_term] != false,
          for_rent_short_term: data[:rental][:short_term] || false,
          furnished: data[:rental][:furnished] || false,
          price_rental_monthly_current_cents: data[:rental][:monthly_price_cents],
          price_rental_monthly_current_currency: config.dig(:website, :currency) || 'EUR'
        )
        # Set translations
        (config.dig(:website, :supported_locales) || ['en']).each do |locale|
          title = data[:rental].dig(:title, locale.to_sym) || data[:rental][:title]
          desc = data[:rental].dig(:description, locale.to_sym) || data[:rental][:description]
          listing.send("title_#{locale}=", title) if title && listing.respond_to?("title_#{locale}=")
          listing.send("description_#{locale}=", desc) if desc && listing.respond_to?("description_#{locale}=")
        end
        listing.save!
      end

      # Add features
      if data[:features]
        data[:features].each do |feature_key|
          asset.features.find_or_create_by!(feature_key: feature_key)
        end
      end

      # Attach image if provided
      attach_property_image(asset, data[:image]) if data[:image]

      asset
    end

    def attach_property_image(asset, image_filename)
      # Skip if already has photos
      return if asset.prop_photos.any?

      # Prefer external URLs to avoid storage bloat
      if Pwb::SeedImages.enabled?
        external_url = Pwb::SeedImages.property_url(image_filename)
        Pwb::PropPhoto.create!(
          realty_asset: asset,
          sort_order: 1,
          external_url: external_url
        )
        log("Set external URL for #{asset.reference}", :detail)
        return
      end

      # Fallback to local file attachment
      # Check pack's images directory first
      image_path = @path.join('images', image_filename)

      # Fall back to shared seed images
      unless image_path.exist?
        image_path = Rails.root.join('db', 'seeds', 'images', image_filename)
      end

      return unless image_path.exist?

      photo = Pwb::PropPhoto.create!(realty_asset: asset, sort_order: 1)
      photo.image.attach(
        io: File.open(image_path),
        filename: image_filename,
        content_type: 'image/jpeg'
      )
      photo.save!
    end

    def users_config
      config[:users] || []
    end

    # ============================================
    # Logging
    # ============================================

    def log(message, level = :info)
      return unless @verbose

      prefix = case level
               when :info then "  "
               when :success then "  ✅ "
               when :warning then "  ⚠️  "
               when :error then "  ❌ "
               when :detail then "    "
               else "  "
               end

      puts "#{prefix}#{message}"
    end
  end
end
