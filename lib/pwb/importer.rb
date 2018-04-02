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
            yml_file_contents = YAML.load_file(file)

            existing_props = []
            new_props = []
            import_host_data = yml_file_contents["import_host_data"]
            import_urls = yml_file_contents["import_urls"]
            # import_host_data = { slug: 're-renting', scraper_name: 'inmo1', host: 're-renting.com' }

            import_host = PropertyWebScraper::ImportHost.find_by_host(import_host_data["host"])
            unless import_host
              import_host = PropertyWebScraper::ImportHost.create!(import_host_data)
            end

            import_urls.each do |import_url|
              import_single_page import_url, import_host, existing_props, new_props
            end

            # TODO - return and log summary to rake task

          end
        end
      end


      def import_single_page url, import_host, existing_props, new_props
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
          prop.save!
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
