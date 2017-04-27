# TODO: - rename as AdminSetup
# Idea is to allow different configs of admin interface
# eg - I might have an "experimental" config with an
# option to hide links to github..
module Pwb
  # https://github.com/zilkey/active_hash
  class ClientSetup < ActiveJSON::Base
    # self.data =
    #   { "us":
    #     {
    #       "id": 1,
    #       "name": "US",
    #       "custom_field_1": "value1"
    #     }
    #     },
    #   { "canada":
    #     {
    #       "id": 2,
    #       "name": "Canada",
    #       "custom_field_2": "value2"
    #     }
    #     }

    set_root_path "#{Pwb::Engine.root}/config/client_setups"
    # set_filename "client_setups"
    use_multiple_files
    set_filenames "default", "us"
  end
end
