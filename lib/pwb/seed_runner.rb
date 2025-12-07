# frozen_string_literal: true

# Pwb::SeedRunner - Enhanced seeding orchestrator with safety features
#
# Features:
# ---------
# - Interactive mode with warnings before updating existing data
# - Dry-run mode to preview changes without applying them
# - Progress logging with detailed output
# - Validation of seed files before processing
# - Support for create-only, update-only, or upsert modes
#
# Usage:
# ------
#   # Interactive mode (default) - prompts before updates
#   Pwb::SeedRunner.run(website: website)
#
#   # Non-interactive mode - skips updates (create-only)
#   Pwb::SeedRunner.run(website: website, mode: :create_only)
#
#   # Force update mode - updates without prompting
#   Pwb::SeedRunner.run(website: website, mode: :force_update)
#
#   # Dry-run mode - shows what would happen without making changes
#   Pwb::SeedRunner.run(website: website, dry_run: true)
#
module Pwb
  class SeedRunner
    MODES = {
      interactive: :interactive,     # Prompts before updating existing records
      create_only: :create_only,     # Only creates new records, skips existing
      force_update: :force_update,   # Updates existing records without prompting
      upsert: :upsert                # Creates or updates all records
    }.freeze

    class << self
      # Main entry point for running seeds with enhanced features
      #
      # @param website [Pwb::Website] The website to seed data for
      # @param mode [Symbol] One of :interactive, :create_only, :force_update, :upsert
      # @param dry_run [Boolean] If true, shows what would happen without making changes
      # @param skip_properties [Boolean] If true, skip seeding sample properties
      # @param skip_translations [Boolean] If true, skip seeding translations
      # @param verbose [Boolean] If true, show detailed progress output
      def run(website: nil, mode: :interactive, dry_run: false, skip_properties: false, 
              skip_translations: false, verbose: true)
        runner = new(
          website: website,
          mode: mode,
          dry_run: dry_run,
          skip_properties: skip_properties,
          skip_translations: skip_translations,
          verbose: verbose
        )
        runner.execute
      end
    end

    attr_reader :website, :mode, :dry_run, :skip_properties, :skip_translations, :verbose
    attr_reader :stats

    def initialize(website:, mode:, dry_run:, skip_properties:, skip_translations:, verbose:)
      @website = website || Pwb::Website.first || create_default_website
      @mode = mode
      @dry_run = dry_run
      @skip_properties = skip_properties
      @skip_translations = skip_translations
      @verbose = verbose
      @stats = { created: 0, updated: 0, skipped: 0, errors: 0 }
      @user_choice = nil # Cache user's choice for batch operations
    end

    def execute
      log_header
      validate_seed_files
      
      if dry_run
        log "🔍 DRY RUN MODE - No changes will be made", :warning
        log ""
      end

      # Show warning if there's existing data that might be updated
      if mode == :interactive && has_existing_data?
        unless confirm_update_warning
          log "❌ Seeding cancelled by user", :error
          return false
        end
      end

      seed_translations unless skip_translations
      seed_agency
      seed_website_settings
      seed_field_keys
      seed_users
      seed_contacts
      seed_links
      seed_properties unless skip_properties
      seed_pages
      
      log_summary
      true
    rescue StandardError => e
      log "❌ Seeding failed: #{e.message}", :error
      log e.backtrace.first(5).join("\n"), :error if verbose
      false
    end

    private

    def create_default_website
      Pwb::Website.create!(
        subdomain: 'default',
        theme_name: 'bristol',
        default_currency: 'EUR',
        default_client_locale: 'en-UK'
      )
    end

    def log_header
      log "=" * 60
      log "🌱 PWB Seed Runner"
      log "=" * 60
      log "Website: #{website.subdomain || website.slug || 'default'} (ID: #{website.id})"
      log "Mode: #{mode}"
      log "Dry Run: #{dry_run}"
      log "Skip Properties: #{skip_properties}"
      log "=" * 60
      log ""
    end

    def log_summary
      log ""
      log "=" * 60
      log "📊 Seeding Summary"
      log "=" * 60
      log "   Created: #{stats[:created]}"
      log "   Updated: #{stats[:updated]}"
      log "   Skipped: #{stats[:skipped]}"
      log "   Errors:  #{stats[:errors]}"
      log "=" * 60
      log dry_run ? "✅ Dry run complete" : "✅ Seeding complete"
    end

    def validate_seed_files
      log "📋 Validating seed files...", :info
      
      required_files = %w[
        agency.yml
        agency_address.yml
        website.yml
        field_keys.yml
        users.yml
        contacts.yml
        links.yml
      ]
      
      missing_files = []
      required_files.each do |file|
        path = Rails.root.join("db", "yml_seeds", file)
        unless File.exist?(path)
          missing_files << file
        end
      end
      
      if missing_files.any?
        log "⚠️  Missing seed files: #{missing_files.join(', ')}", :warning
      else
        log "   ✓ All required seed files found", :success
      end
    end

    def has_existing_data?
      website.contacts.any? ||
        website.field_keys.any? ||
        website.links.any? ||
        website.props.any?
    end

    def confirm_update_warning
      return true unless $stdin.tty? # Non-interactive environment
      
      log ""
      log "⚠️  " + "=" * 56, :warning
      log "⚠️  WARNING: EXISTING DATA DETECTED", :warning
      log "⚠️  " + "=" * 56, :warning
      log ""
      log "The following existing data was found for this website:"
      log "   • Contacts: #{website.contacts.count}"
      log "   • Field Keys: #{website.field_keys.count}"
      log "   • Links: #{website.links.count}"
      log "   • Properties: #{website.props.count}"
      log ""
      log "What would you like to do?"
      log ""
      log "   [C] Create only - Skip existing records, only create new ones"
      log "   [U] Update all  - Update existing records with seed data"
      log "   [Q] Quit        - Cancel seeding and exit"
      log ""
      
      print "Your choice [C/U/Q]: "
      
      choice = $stdin.gets&.strip&.upcase
      
      case choice
      when 'C'
        @mode = :create_only
        log ""
        log "✓ Proceeding with CREATE ONLY mode", :success
        true
      when 'U'
        @mode = :force_update
        log ""
        log "✓ Proceeding with UPDATE mode - existing data will be modified", :warning
        true
      when 'Q', nil
        false
      else
        log "Invalid choice. Please enter C, U, or Q.", :error
        confirm_update_warning
      end
    end

    def seed_translations
      log "📚 Seeding translations...", :info
      
      translation_files = %w[
        translations_ca.rb translations_en.rb translations_es.rb translations_de.rb
        translations_fr.rb translations_it.rb translations_nl.rb translations_pl.rb
        translations_pt.rb translations_ro.rb translations_ru.rb translations_ko.rb
        translations_bg.rb
      ]
      
      # Only load if count is low or in test environment
      current_count = I18n::Backend::ActiveRecord::Translation.count
      if current_count <= 600 || Rails.env.test?
        translation_files.each do |file|
          path = File.join(Rails.root, 'db', 'seeds', file)
          if File.exist?(path)
            load path unless dry_run
            log "   ✓ Loaded #{file}", :success if verbose
          end
        end
      else
        log "   ⏭️  Skipping translations (#{current_count} already exist)", :info
        stats[:skipped] += translation_files.count
      end
    end

    def seed_agency
      log "🏢 Seeding agency...", :info
      
      agency_yml = load_seed_yml("agency.yml")
      agency = website.agency || website.build_agency
      
      if agency.persisted? && agency.display_name.present?
        handle_existing_record("Agency", agency, agency_yml)
      else
        unless dry_run
          agency.update!(agency_yml)
          
          # Handle agency address
          agency_address_yml = load_seed_yml("agency_address.yml")
          agency_address = agency.primary_address || Pwb::Address.create!(agency_address_yml)
          agency.update!(primary_address: agency_address)
          website.update!(agency: agency) unless website.agency
        end
        log "   ✓ Agency created/updated", :success
        stats[:created] += 1
      end
    end

    def seed_website_settings
      log "🌐 Seeding website settings...", :info
      
      website_yml = load_seed_yml("website.yml")
      
      if website.company_display_name.present?
        handle_existing_record("Website settings", website, website_yml)
      else
        website.update!(website_yml) unless dry_run
        log "   ✓ Website settings updated", :success
        stats[:updated] += 1
      end
    end

    def seed_field_keys
      log "🔑 Seeding field keys...", :info
      
      # Check if website association is available
      unless Pwb::FieldKey.column_names.include?('pwb_website_id')
        log "   ⚠️  Field keys not scoped by website (pwb_website_id column not found)", :warning
        seed_field_keys_without_website_scope
        return
      end
      
      field_keys_yml = load_seed_yml("field_keys.yml")
      
      field_keys_yml.each do |field_key_data|
        global_key = field_key_data["global_key"]
        existing = website.field_keys.find_by(global_key: global_key)
        
        if existing
          handle_existing_record("FieldKey '#{global_key}'", existing, field_key_data, inline: true)
        else
          unless dry_run
            website.field_keys.create!(field_key_data)
          end
          log "   ✓ Created field key: #{global_key}", :success if verbose
          stats[:created] += 1
        end
      end
    end

    def seed_field_keys_without_website_scope
      field_keys_yml = load_seed_yml("field_keys.yml")
      
      field_keys_yml.each do |field_key_data|
        global_key = field_key_data["global_key"]
        existing = Pwb::FieldKey.find_by(global_key: global_key)
        
        if existing
          handle_existing_record("FieldKey '#{global_key}'", existing, field_key_data, inline: true)
        else
          unless dry_run
            Pwb::FieldKey.create!(field_key_data)
          end
          log "   ✓ Created field key: #{global_key}", :success if verbose
          stats[:created] += 1
        end
      end
    end

    def seed_users
      log "👤 Seeding users...", :info

      users_yml = load_seed_yml("users.yml")

      users_yml.each do |user_data|
        email = user_data["email"]
        existing = Pwb::User.find_by(email: email)

        user = if existing
                 handle_existing_record("User '#{email}'", existing, user_data, inline: true)
                 existing
               else
                 unless dry_run
                   user_data["website_id"] ||= website.id
                   new_user = Pwb::User.create!(user_data)
                   log "   ✓ Created user: #{email}", :success if verbose
                   stats[:created] += 1
                   new_user
                 end
               end

        # Create membership for the user based on role (if user exists)
        next unless user && !dry_run

        role = user_data["role"] || (user_data["admin"] ? "admin" : "member")
        membership_role = case role.to_s
                          when "admin", "owner" then role.to_s
                          when "agent" then "member"
                          else "member"
                          end

        Pwb::UserMembership.find_or_create_by!(user: user, website: website) do |m|
          m.role = membership_role
          m.active = true
        end
      end
    end

    def seed_contacts
      log "📇 Seeding contacts...", :info
      
      # Check if website_id column exists on contacts table
      unless Pwb::Contact.column_names.include?('website_id')
        log "   ⚠️  Skipping contacts (website_id column not found - run migrations)", :warning
        return
      end
      
      contacts_yml = load_seed_yml("contacts.yml")
      
      contacts_yml.each do |contact_data|
        email = contact_data["primary_email"] || contact_data["email"]
        existing = website.contacts.find_by(primary_email: email)
        
        if existing
          handle_existing_record("Contact '#{email}'", existing, contact_data, inline: true)
        else
          unless dry_run
            website.contacts.create!(contact_data)
          end
          log "   ✓ Created contact: #{email}", :success if verbose
          stats[:created] += 1
        end
      end
    end

    def seed_links
      log "🔗 Seeding links...", :info
      
      links_yml = load_seed_yml("links.yml")
      
      links_yml.each do |link_data|
        slug = link_data["slug"]
        existing = website.links.find_by(slug: slug)
        
        if existing
          handle_existing_record("Link '#{slug}'", existing, link_data, inline: true)
        else
          unless dry_run
            link = website.links.create!(link_data)
            set_link_translations(link, link_data)
          end
          log "   ✓ Created link: #{slug}", :success if verbose
          stats[:created] += 1
        end
      end
    end

    def seed_properties
      log "🏠 Seeding properties...", :info
      
      if website.props.count > 3
        log "   ⏭️  Skipping properties (#{website.props.count} already exist)", :info
        return
      end
      
      prop_files = %w[
        villa_for_sale.yml villa_for_rent.yml
        flat_for_sale.yml flat_for_rent.yml
        flat_for_sale_2.yml flat_for_rent_2.yml
      ]
      
      prop_files.each do |file|
        seed_property_file(file)
      end
    end

    def seed_property_file(yml_file)
      prop_seed_file = Rails.root.join("db", "yml_seeds", "prop", yml_file)
      return unless File.exist?(prop_seed_file)
      
      prop_yml = YAML.load_file(prop_seed_file)
      prop_yml.each do |prop_data|
        reference = prop_data["reference"]
        existing = website.props.find_by(reference: reference)
        
        if existing
          handle_existing_record("Property '#{reference}'", existing, prop_data, inline: true)
        else
          unless dry_run
            photos = extract_photos(prop_data)
            prop = website.props.create!(prop_data)
            attach_photos(prop, photos)
          end
          log "   ✓ Created property: #{reference}", :success if verbose
          stats[:created] += 1
        end
      end
    end

    def seed_pages
      log "📄 Seeding pages and page parts...", :info
      
      unless dry_run
        Pwb::PagesSeeder.seed_page_parts!
        Pwb::PagesSeeder.seed_page_basics!(website: website)
        Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
      end
      
      log "   ✓ Pages and page parts seeded", :success
    end

    # Handle an existing record based on the current mode
    def handle_existing_record(name, record, new_data, inline: false)
      case mode
      when :create_only
        log "   ⏭️  Skipped #{name} (already exists)", :info if verbose || !inline
        stats[:skipped] += 1
      when :force_update, :upsert
        unless dry_run
          record.update!(new_data.except('id', 'created_at', 'updated_at'))
        end
        log "   ✓ Updated #{name}", :success if verbose || !inline
        stats[:updated] += 1
      when :interactive
        # In interactive mode, we already asked the user at the start
        # Default to create_only behavior
        log "   ⏭️  Skipped #{name} (already exists)", :info if verbose || !inline
        stats[:skipped] += 1
      end
    end

    def set_link_translations(link, link_data)
      I18n.available_locales.each do |locale|
        title_accessor = "link_title_#{locale}"
        next unless link.respond_to?(title_accessor)
        next if link.send(title_accessor).present?
        
        if link_data["page_slug"]
          translation_key = "navbar.#{link_data['page_slug']}"
          title_value = I18n.t(translation_key, locale: locale, default: nil)
          title_value ||= I18n.t(translation_key, locale: :en, default: "Unknown")
        end
        title_value ||= link.link_title
        link.update_attribute(title_accessor, title_value)
      end
    end

    def extract_photos(prop_data)
      photos = []
      if prop_data["photo_urls"].present?
        photos = prop_data.delete("photo_urls")
      elsif prop_data["photo_files"].present?
        photos = prop_data.delete("photo_files")
      end
      photos
    end

    def attach_photos(prop, photo_sources)
      return if photo_sources.empty? || Rails.env.test?
      
      # Delegate to existing photo creation logic in Seeder
      # This is intentionally simplified - the Seeder has robust photo handling
    end

    def load_seed_yml(yml_file)
      seed_file = Rails.root.join("db", "yml_seeds", yml_file)
      raise "Seed file not found: #{yml_file}" unless File.exist?(seed_file)
      YAML.load_file(seed_file) || []
    end

    def log(message, level = :info)
      return unless verbose || level == :error || level == :warning
      
      prefix = case level
               when :success then "\e[32m"  # Green
               when :warning then "\e[33m"  # Yellow
               when :error   then "\e[31m"  # Red
               else ""
               end
      suffix = prefix.empty? ? "" : "\e[0m"
      
      puts "#{prefix}#{message}#{suffix}"
    end
  end
end
