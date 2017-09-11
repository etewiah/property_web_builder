module Pwb
  class CmsDataLoader
    class << self
#       # Called by this rake task:
#       # rake app:pwb:db:seed    
#       # or from console:
#       # require 'pwb/cms_data_loader'
#       # Pwb::CmsDataLoader.load_site_data!

#       def load_site_data! 
#         locale = "en"
#         # site_key = "cms"
#         from  = "cms"
#         to    = "cms-site"
# # byebug
#         cms = Comfy::Cms::Site.find_or_create_by(
#           {
#             locale: locale,
#             label: to,
#             hostname: "default",
#             identifier: to,
#             path: "/#{locale}"
#           }
#         )
        
#         puts "Importing CMS Fixtures from Folder [#{from}] to Site [#{to}] ..."

#         # changing so that logger is going straight to screen
#         logger = ComfortableMexicanSofa.logger
#         ComfortableMexicanSofa.logger = Logger.new(STDOUT)
#         ComfortableMexicanSofa::Fixture::Importer.new(from, to, :force).import!
#         ComfortableMexicanSofa.logger = logger

#       end

    end
  end
end
