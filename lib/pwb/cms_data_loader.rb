module Pwb
  class CmsDataLoader
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵

      def load_site_by_locale! locale
        site_key = "cms-#{locale}"
        from  = site_key
        to    = site_key

        cms = Comfy::Cms::Site.find_or_create_by(
          {
            locale: locale,
            label: site_key,
            hostname: "default",
            identifier: site_key,
            path: "/#{locale}"
          }
        )
        
        puts "Importing CMS Fixtures from Folder [#{from}] to Site [#{to}] ..."

        # changing so that logger is going straight to screen
        logger = ComfortableMexicanSofa.logger
        ComfortableMexicanSofa.logger = Logger.new(STDOUT)
        ComfortableMexicanSofa::Fixture::Importer.new(from, to, :force).import!
        ComfortableMexicanSofa.logger = logger

      end

    end
  end
end
