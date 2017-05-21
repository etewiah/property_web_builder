module Pwb
  # https://github.com/zilkey/active_hash
  class CmsPageContainer < ActiveJSON::Base
    set_root_path "#{Pwb::Engine.root}/config/cms_page_containers"
    # set_filename "client_setups"
    use_multiple_files
    set_filenames "about-us"
  end
end
