# To reload from console:
# load "#{Pwb::Engine.root}/lib/pwb/importer.rb"
# Pwb::Importer.import!
module Pwb
  class Importer
    class << self
      # Called by this rake task:
      # rake app:pwb:import_from_urls
      def import!

        import_sources_dir = Pwb::Engine.root.join('db', 'import_sources', 'enabled')
        import_sources_dir.children.each do |file|
          if file.extname == ".yml"
            yml_file_content = YAML.load_file(file)

            existing_props = []
            new_props = []
            import_host_data = yml_file_content["import_host_data"]
            import_urls = yml_file_content["import_urls"]
            # import_host_data = { slug: 're-renting', scraper_name: 'inmo1', host: 're-renting.com' }

            import_host = PropertyWebScraper::ImportHost.find_by_host(import_host_data["host"])
            unless import_host
              import_host = PropertyWebScraper::ImportHost.create!(import_host_data)
            end

            max_photos_to_process = yml_file_content["max_photos_to_process"] || 1
            locales = yml_file_content["locales"] || I18n.available_locales
            
            creator_params = {
              max_photos_to_process: max_photos_to_process,
              locales: locales
            }

            # creator_params["locales"] = I18n.available_locales

            # TODO: - allow above to be set in config yml file
            # as well as additional values for deciding how long to wait between scraping
            # Should also allow passing in of a scraper mapping file

            import_urls.each do |import_url|
              puts "importing from #{import_url}"
              import_single_page import_url, import_host, existing_props, new_props, creator_params
            end

            # TODO - return and log summary to rake task

          end
        end
      end


      def import_single_page url, import_host, existing_props, new_props, creator_params
        uri = uri_from_url url.strip
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          error = {
            success: false,
            error_message: "Please provide a valid url"
          }
          return error
        end

        # miTODO: - allow params to PropertyWebScraper::Scraper to decide expiry age etc.
        web_scraper = PropertyWebScraper::Scraper.new(import_host.scraper_name)
        # PropertyWebScraper::Scraper also allows passing in a ScraperMapping as the 
        # second param (for cases where PWS does not have it set up)..

        listing = web_scraper.process_url uri.to_s, import_host
        pws_listing = PropertyWebScraper::PwbListing.find listing.id

        # unless pws_listing.reference.present?
        #   if pws_listing.street_address
        #   end
        # end

        if Pwb::Prop.where(import_url: pws_listing.import_url).exists?
          existing_props.push Pwb::Prop.find_by_import_url pws_listing.import_url
          # propertyJSON
          puts "#{pws_listing.import_url} already exists"
        else
          new_prop_json = pws_listing.as_json
          # need to find out why import_url is not included in as_json
          new_prop_json["import_url"] =  pws_listing.import_url
          prop_creator = Pwb::PropCreator.new(new_prop_json, creator_params)
          prop = prop_creator.create_from_json
          # prop = PropFromPwsListing pws_listing.as_json
          # TODO - have some logic for when to make visible
          prop.visible = true
          prop.save!
          puts "#{pws_listing.import_url} created"
        end
      end


      protected

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
