# To reload from console:
# load "#{Pwb::Engine.root}/lib/pwb/importer.rb"
#Pwb::Importer.import!
module Pwb
  class Importer
    class << self

      def import!

        import_sources_dir = Pwb::Engine.root.join('db', 'import_sources', 'enabled')
        import_sources_dir.children.each do |file|
          if file.extname == ".yml"
            # page_part_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'page_parts', yml_file_name)
            yml_file_contents = YAML.load_file(file)

            existing_props = []
            import_host_data = yml_file_contents["import_host_data"]
            import_urls = yml_file_contents["import_urls"]
            # import_host_data = { slug: 'laventa', scraper_name: 'pwb', host: 'www.laventa-mallorca.com' }
            # import_host_data = { slug: 're-renting', scraper_name: 'inmo1', host: 're-renting.com' }

            import_host = PropertyWebScraper::ImportHost.find_by_host(import_host_data[:host])
            unless import_host
              import_host = PropertyWebScraper::ImportHost.create!(import_host_data)
            end

            # url = "http://re-renting.com/en/properties/for-rent/1/acogedor-piso-en-anton-martin"

            import_urls.each do |import_url|
              import_single_page import_url, import_host              
            end

          end
        end
      end


      def import_single_page url, import_host
        uri = uri_from_url url.strip
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          error = {
            success: false,
            error_message: "Please provide a valid url"
          }
          return error
        end

        web_scraper = PropertyWebScraper::Scraper.new(import_host.scraper_name)
        listing = web_scraper.process_url uri.to_s, import_host

        pws_listing = PropertyWebScraper::PwbListing.find listing.id

        if Pwb::Prop.where(reference: pws_listing.reference).exists?
          existing_props.push Pwb::Prop.find_by_reference pws_listing.reference
          # propertyJSON
        else
          prop_creator = Pwb::PropCreator.new(pws_listing.as_json)
          prop = prop_creator.create
          # prop = PropFromPwsListing pws_listing.as_json
          # TODO - have some logic for when to make visible
          prop.visible = true
          prop.save!        end
      end

      protected


      # def PropFromPwsListing propertyJSON
      #   # TODO: pass in locales
      #   locales = ["en","es"]
      #   # TODO: ensure reference is created (calculate from lat lng if necessary)
      #   # and add geocoding option
      #   new_prop = Pwb::Prop.create(propertyJSON.except("locale_code","features","property_photos"))
      #   # new_prop = Pwb::Prop.create(propertyJSON.except("features", "property_photos", "image_urls", "last_retrieved_at"))

      #   # create will use website defaults for currency and area_unit
      #   # need to override that
      #   if propertyJSON["currency"]
      #     new_prop.currency = propertyJSON["currency"]
      #     new_prop.save!
      #   end
      #   if propertyJSON["area_unit"]
      #     new_prop.area_unit = propertyJSON["area_unit"]
      #     new_prop.save!
      #   end

      #   # TODO - go over supported locales and save title and description
      #   # into them

      #   if propertyJSON["features"]
      #     # new_prop.set_features=propertyJSON["features"]
      #     propertyJSON["features"].each do |feature_name|
      #       feature_translation_model = I18n::Backend::ActiveRecord::Translation.find_by_value(feature_name.strip)
      #       if feature_translation_model
      #         feature_key = feature_translation_model.key
      #       else
      #         feature_key = "features." + feature_name.camelize(:lower).delete(" \t\r\n")
      #         locales.each do |locale|
      #           # not much I can do other than set all locales to the translation I know of
      #           # Admin can go in later and edit them
      #           I18n::Backend::ActiveRecord::Translation.create!(
      #           {locale: locale, key: feature_key, value: feature_name.strip})
      #         end
      #       end
      #       new_prop.features.find_or_create_by( feature_key: feature_key)
      #     end
      #   end
      #   if propertyJSON["property_photos"]
      #     # uploading images can slow things down so worth setting a limit
      #     max_photos_to_process = 2
      #     # TODO - retrieve above as a param
      #     propertyJSON["property_photos"].each_with_index do |property_photo, index|
      #       if index > max_photos_to_process
      #         break
      #       end
      #       photo = Pwb::PropPhoto.create
      #       photo.sort_order = property_photo["sort_order"] || nil
      #       photo.remote_image_url = property_photo["url"] || property_photo[:url]
      #       # photo.remote_image_url = property_photo["image"]["url"] || property_photo["url"]
      #       photo.save!
      #       new_prop.prop_photos.push photo
      #     end
      #   end
      #   return new_prop
      # end

      def uri_from_url import_url
        begin
          uri = URI.parse import_url
        rescue URI::InvalidURIError => error
          uri = ""
        end
      end

    end
  end
end
