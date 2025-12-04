# To reload from console:
# load "#{Rails.root}/lib/pwb/seeder.rb"
#
# Multi-tenancy Support:
# ----------------------
# The seeder now supports multi-tenancy by accepting a `website` parameter.
# When seeding for a specific tenant, pass the website instance:
#
#   website = Pwb::Website.find_by(subdomain: 'my-tenant')
#   Pwb::Seeder.seed!(website: website)
#
# If no website is provided, it defaults to the first website in the database.
#
# Data that is scoped to a website (props, links, agency) will be associated
# with the provided website. Shared data (translations, users, field_keys)
# is only seeded once.
#
# Optional Property Seeding:
# --------------------------
# By default, sample properties are seeded. To skip property seeding:
#
#   Pwb::Seeder.seed!(website: website, skip_properties: true)
#
# This is useful for production environments where you don't want demo data.
#
# Note on Property Models:
# ------------------------
# This seeder creates properties using Pwb::Prop (the legacy model).
# Pwb::Property is a READ-ONLY materialized view for optimized queries.
# Do NOT use Pwb::Property.create! - it will raise ActiveRecord::ReadOnlyRecord.
# The materialized view is automatically refreshed when Pwb::RealtyAsset,
# Pwb::SaleListing, or Pwb::RentalListing records are modified.
#
module Pwb
  class Seeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵
      #
      # @param website [Pwb::Website] The website to seed data for (optional)
      # @param skip_properties [Boolean] If true, skip seeding sample properties (default: false)
      def seed!(website: nil, skip_properties: false)
        @current_website = website || Pwb::Website.first || Pwb::Website.create!(theme_name: 'bristol')
        @skip_properties = skip_properties
        
        I18n.locale = :en
        # unless ENV["RAILS_ENV"] == "test"
        #   load File.join(Rails.root, 'db', 'seeds', 'translations.rb')
        # end
        # In test environment, always reload translations
        # In other environments, only load if count is low
        should_load_translations = ENV["RAILS_ENV"] == "test" || I18n::Backend::ActiveRecord::Translation.all.length <= 600
        if should_load_translations
          # TODO: look in a directory and load all the files there
          load File.join(Rails.root, "db", "seeds", "translations_ca.rb")
          load File.join(Rails.root, "db", "seeds", "translations_en.rb")
          load File.join(Rails.root, "db", "seeds", "translations_es.rb")
          load File.join(Rails.root, "db", "seeds", "translations_de.rb")
          load File.join(Rails.root, "db", "seeds", "translations_fr.rb")
          load File.join(Rails.root, "db", "seeds", "translations_it.rb")
          load File.join(Rails.root, "db", "seeds", "translations_nl.rb")
          load File.join(Rails.root, "db", "seeds", "translations_pl.rb")
          load File.join(Rails.root, "db", "seeds", "translations_pt.rb")
          load File.join(Rails.root, "db", "seeds", "translations_ro.rb")
          load File.join(Rails.root, "db", "seeds", "translations_ru.rb")
          load File.join(Rails.root, "db", "seeds", "translations_ko.rb")
          load File.join(Rails.root, "db", "seeds", "translations_bg.rb")
        end

        # seed_sections 'sections.yml'
        # seed_content 'content_columns.yml'
        # seed_content 'carousel.yml'
        # seed_content 'about_us.yml'
        # seed_content 'static.yml'
        # seed_content 'footer.yml'
        # seed_content 'sell.yml'
        seed_agency "agency.yml"
        # need to seed website first so correct currency is used
        seed_website "website.yml"
        # currency passed in for properties is ignored in favour
        # of default website currency
        seed_properties unless @skip_properties
        seed_field_keys "field_keys.yml"
        seed_users "users.yml"
        seed_contacts "contacts.yml"
        # seed_pages
        seed_links "links.yml"
      end

      protected
      
      # Returns the current website being seeded
      def current_website
        @current_website
      end
      
      # Seeds sample properties for the current website
      # Only seeds if the website has fewer than 4 properties
      def seed_properties
        unless @current_website.props.count > 3
          puts "   🏠 Seeding sample properties..."
          seed_prop "villa_for_sale.yml"
          seed_prop "villa_for_rent.yml"
          seed_prop "flat_for_sale.yml"
          seed_prop "flat_for_rent.yml"
          seed_prop "flat_for_sale_2.yml"
          seed_prop "flat_for_rent_2.yml"
        end

        # Backfill normalized records for any existing props that don't have them
        backfill_normalized_records

        # Refresh the materialized view to include all properties
        puts "   🔄 Refreshing properties materialized view..."
        Pwb::Property.refresh
      end

      # Backfills normalized records (RealtyAsset, listings) for existing Pwb::Prop records
      # that don't already have corresponding RealtyAsset records
      def backfill_normalized_records
        props_without_assets = @current_website.props.where.not(
          reference: Pwb::RealtyAsset.where(website: @current_website).select(:reference)
        )

        return if props_without_assets.empty?

        puts "   🔄 Backfilling #{props_without_assets.count} properties to normalized tables..."

        props_without_assets.find_each do |prop|
          backfill_prop_to_normalized(prop)
        end
      end

      # Converts a single Pwb::Prop to normalized records
      def backfill_prop_to_normalized(prop)
        # Build prop_data hash from the prop attributes
        prop_data = prop.attributes.merge(
          "currency" => prop.currency || "EUR"
        )

        # Add translations from Mobility JSONB column
        if prop.translations.present?
          prop.translations.each do |locale, attrs|
            prop_data["title_#{locale}"] = attrs['title'] if attrs['title'].present?
            prop_data["description_#{locale}"] = attrs['description'] if attrs['description'].present?
          end
        end

        create_normalized_property_records(prop_data, [])
      end

      def seed_contacts(yml_file)
        contacts_yml = load_seed_yml yml_file
        contacts_yml.each do |contact_yml|
          # Check if contact already exists for this website
          existing_contact = current_website.contacts.find_by(primary_email: contact_yml["email"] || contact_yml["primary_email"])
          
          unless existing_contact.present?
            # Create contact with website association for proper multi-tenancy scoping
            current_website.contacts.create!(contact_yml)
          end
        end
      end

      def seed_users(yml_file)
        users_yml = load_seed_yml yml_file
        users_yml.each do |user_yml|
          unless Pwb::User.where(email: user_yml["email"]).count > 0
            # Ensure website association if required
            if Pwb::User.reflect_on_association(:website)
              user_yml["website_id"] ||= @current_website.id if @current_website
            end
            Pwb::User.create!(user_yml)
          end
        end
      end

      def seed_field_keys(yml_file)
        field_keys_yml = load_seed_yml yml_file
        field_keys_yml.each do |field_key_yml|
          global_key = field_key_yml["global_key"]

          # Check if field_key already exists globally (unique constraint on global_key)
          existing_field_key = Pwb::FieldKey.find_by(global_key: global_key)

          if existing_field_key.present?
            # If it exists but belongs to a different website, associate it with current website too
            # For now, we skip since field_keys are shared configuration
            next
          end

          # Create field_key with website association
          current_website.field_keys.create!(field_key_yml)
        end
      end

      def seed_links(yml_file)
        links_yml = load_seed_yml yml_file
        links_yml.each do |single_link_yml|
          # Check if this link already exists for this website
          link_record = current_website.links.find_by(slug: single_link_yml["slug"])
          
          unless link_record.present?
            # Create link with website association
            link_record = current_website.links.create!(single_link_yml)
          end

          # below sets the link title text from I18n translations
          # because setting the value in links.yml for each language
          # is not feasible
          I18n.available_locales.each do |locale|
            title_accessor = "link_title_" + locale.to_s
            # if link_title has not been set for this locale
            next unless link_record.send(title_accessor).blank?
            # if link is associated with a page
            if single_link_yml["page_slug"]
              translation_key = "navbar." + single_link_yml["page_slug"]
              # get the I18n translation
              title_value = I18n.t(translation_key, locale: locale, default: nil)
              title_value ||= I18n.t(translation_key, locale: :en, default: "Unknown")
            end
            # in case translation cannot be found or link not associated with a page
            # take default link_title (English value)
            title_value ||= link_record.link_title
            # set title_value as link_title
            link_record.update_attribute title_accessor, title_value
          end
        end
      end

      def seed_website(yml_file)
        website_yml = load_seed_yml yml_file
        # Use the current website being seeded
        website = current_website
        unless website.company_display_name.present?
          website.update!(website_yml)
        end
      end

      def seed_agency(yml_file)
        agency_yml = load_seed_yml yml_file
        # Find or create agency for the current website
        agency = current_website.agency || current_website.build_agency
        unless agency.display_name.present?
          agency.update!(agency_yml)
          agency_address_yml = load_seed_yml "agency_address.yml"
          agency_address = Pwb::Address.create!(agency_address_yml)
          agency.primary_address = agency_address
          agency.save!
          # Associate agency with website if not already
          current_website.update!(agency: agency) unless current_website.agency
        end
      end

      def seed_prop(yml_file)
        prop_seed_file = Rails.root.join("db", "yml_seeds", "prop", yml_file)
        prop_yml = YAML.load_file(prop_seed_file)
        prop_yml.each do |single_prop_yml|
          reference = single_prop_yml["reference"]

          # Check if prop exists for this website
          next if current_website.props.where(reference: reference).count > 0

          photos = []
          if single_prop_yml["photo_urls"].present?
            photos = create_photos_from_urls single_prop_yml["photo_urls"], Pwb::PropPhoto
            single_prop_yml.except! "photo_urls"
          end
          if single_prop_yml["photo_files"].present?
            photos = create_photos_from_files single_prop_yml["photo_files"], Pwb::PropPhoto
            single_prop_yml.except! "photo_files"
          end

          # Create prop with website association (legacy model)
          new_prop = current_website.props.create!(single_prop_yml)

          # Attach photos to the legacy prop
          photos.each do |photo|
            photo.update!(prop_id: new_prop.id)
          end if photos.any?

          # Also create normalized records (RealtyAsset + Listings) for the materialized view
          create_normalized_property_records(single_prop_yml, photos)
        end
      end

      # Creates normalized property records (RealtyAsset, SaleListing, RentalListing)
      # from the legacy prop YAML data. This populates the materialized view.
      def create_normalized_property_records(prop_data, photos = [])
        # Extract asset attributes from prop data
        # Only include columns that exist in RealtyAsset table
        asset_attrs = {
          website: current_website,
          reference: prop_data["reference"],
          year_construction: prop_data["year_construction"],
          count_bedrooms: prop_data["count_bedrooms"],
          count_bathrooms: prop_data["count_bathrooms"],
          count_toilets: prop_data["count_toilets"],
          count_garages: prop_data["count_garages"],
          plot_area: prop_data["plot_area"],
          constructed_area: prop_data["constructed_area"],
          energy_rating: prop_data["energy_rating"],
          energy_performance: prop_data["energy_performance"],
          street_address: prop_data["street_address"],
          street_name: prop_data["street_name"],
          street_number: prop_data["street_number"],
          postal_code: prop_data["postal_code"],
          city: prop_data["city"],
          region: prop_data["region"],
          country: prop_data["country"],
          latitude: prop_data["latitude"],
          longitude: prop_data["longitude"],
          prop_type_key: prop_data["prop_type_key"],
          prop_state_key: prop_data["prop_state_key"],
          prop_origin_key: prop_data["prop_origin_key"]
        }.compact

        # Check if already exists
        return if Pwb::RealtyAsset.exists?(website: current_website, reference: prop_data["reference"])

        asset = Pwb::RealtyAsset.create!(asset_attrs)

        # Create sale listing if for_sale
        if prop_data["for_sale"]
          Pwb::SaleListing.create!(
            realty_asset: asset,
            visible: prop_data["visible"] || false,
            highlighted: prop_data["highlighted"] || false,
            archived: prop_data["archived"] || false,
            reserved: prop_data["reserved"] || false,
            price_sale_current_cents: prop_data["price_sale_current_cents"] || 0,
            price_sale_current_currency: prop_data["currency"] || "EUR",
            commission_cents: prop_data["commission_cents"] || 0,
            commission_currency: prop_data["commission_currency"] || "EUR"
          )
        end

        # Create rental listing if for_rent
        if prop_data["for_rent_long_term"] || prop_data["for_rent_short_term"]
          Pwb::RentalListing.create!(
            realty_asset: asset,
            visible: prop_data["visible"] || false,
            highlighted: prop_data["highlighted"] || false,
            archived: prop_data["archived"] || false,
            reserved: prop_data["reserved"] || false,
            furnished: prop_data["furnished"] || false,
            for_rent_long_term: prop_data["for_rent_long_term"] || false,
            for_rent_short_term: prop_data["for_rent_short_term"] || false,
            price_rental_monthly_current_cents: prop_data["price_rental_monthly_current_cents"] || 0,
            price_rental_monthly_current_currency: prop_data["currency"] || "EUR"
          )
        end

        # Create translations for the asset
        # Set translations on the prop using Mobility JSONB column
        prop = current_website.props.find_by(reference: prop_data["reference"])
        if prop
          %w[en es ca de fr it nl pl pt ro ru ko bg].each do |locale|
            title = prop_data["title_#{locale}"]
            description = prop_data["description_#{locale}"]
            next unless title.present? || description.present?

            # Set translations using Mobility locale accessors
            prop.send("title_#{locale}=", title) if title.present? && prop.respond_to?("title_#{locale}=")
            prop.send("description_#{locale}=", description) if description.present? && prop.respond_to?("description_#{locale}=")
          end
          prop.save!
        end

        # Link photos to the asset (they're already created with prop_id)
        photos.each do |photo|
          photo.update!(realty_asset_id: asset.id)
        end if photos.any?

        puts "      ✓ Created normalized records for #{prop_data['reference']}"
        asset
      rescue StandardError => e
        puts "      ✗ Failed to create normalized records for #{prop_data['reference']}: #{e.message}"
        Rails.logger.warn "Failed to create normalized records for #{prop_data['reference']}: #{e.message}"
        Rails.logger.warn e.backtrace.first(3).join("\n")
        nil
      end

      # def seed_content(yml_file)
      #   content_seed_file = Rails.root.join('db', 'yml_seeds', yml_file)
      #   content_yml = YAML.load_file(content_seed_file)
      #   # tag is used to group content for an admin page
      #   # key is camelcase (js style) - used client side to identify each item in a group of content
      #   content_yml.each do |single_content_yml|
      #     # check content does not already exist
      #     next if Pwb::Content.where(key: single_content_yml['key']).count > 0
      #     photos = []
      #     if single_content_yml["photo_urls"].present?
      #       photos = create_photos_from_urls single_content_yml["photo_urls"], Pwb::ContentPhoto
      #       single_content_yml.except! "photo_urls"
      #     end
      #     if single_content_yml["photo_files"].present?
      #       photos = create_photos_from_files single_content_yml["photo_files"], Pwb::ContentPhoto
      #       single_content_yml.except! "photo_files"
      #     end
      #     new_content = Pwb::Content.create!(single_content_yml)
      #     next unless !photos.empty?
      #     photos.each do |photo|
      #       new_content.content_photos.push photo
      #     end
      #   end
      #   print("success!")
      # end

      def create_photos_from_files(photo_files, photo_class)
        photos = []
        if ENV["RAILS_ENV"] == "test"
          # don't create photos for tests
          return photos
        end
        photo_files.each do |photo_file|
          begin
            photo = photo_class.send("create")
            file_path = Rails.root.join(photo_file)

            # Use ActiveStorage attach method
            photo.image.attach(
              io: file_path.open,
              filename: File.basename(photo_file),
              content_type: get_content_type(photo_file)
            )

            photo.save!
            photos.push photo
            puts "Successfully created photo from #{photo_file}"
            sleep 1
          rescue Exception => e
            # log exception to console
            puts "Failed to create photo from #{photo_file}"
            puts e
            if photo
              photo.destroy!
            end
          end
        end
        photos
      end

      def create_photos_from_urls(photo_urls, photo_class)
        photos = []
        if ENV["RAILS_ENV"] == "test"
          # don't create photos for tests
          return photos
        end
        photo_urls.each do |photo_url|
          begin
            photo = photo_class.send("create")

            # For URLs, we need to download the file first
            require 'open-uri'
            downloaded_image = URI.open(photo_url)

            photo.image.attach(
              io: downloaded_image,
              filename: File.basename(photo_url),
              content_type: get_content_type_from_url(photo_url)
            )

            photo.save!
            photos.push photo
            puts "Successfully created photo from #{photo_url}"
          rescue Exception => e
            puts "Failed to create photo from #{photo_url}"
            puts e
            if photo
              photo.destroy!
            end
          end
        end
        photos
      end

      def load_seed_yml(yml_file)
        seed_file = Rails.root.join("db", "yml_seeds", yml_file)
        yml = YAML.load_file(seed_file)
      end

      # Helper method to determine content type from file extension
      def get_content_type(file_path)
        case File.extname(file_path).downcase
        when '.jpg', '.jpeg'
          'image/jpeg'
        when '.png'
          'image/png'
        when '.gif'
          'image/gif'
        when '.webp'
          'image/webp'
        else
          'application/octet-stream'
        end
      end

      # Helper method to determine content type from URL
      def get_content_type_from_url(url)
        case File.extname(URI.parse(url).path).downcase
        when '.jpg', '.jpeg'
          'image/jpeg'
        when '.png'
          'image/png'
        when '.gif'
          'image/gif'
        when '.webp'
          'image/webp'
        else
          'image/jpeg' # Default for images
        end
      end
    end
  end
end
