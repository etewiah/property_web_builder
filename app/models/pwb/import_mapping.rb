module Pwb
  # https://github.com/zilkey/active_hash
  class ImportMapping < ActiveJSON::Base
    # set_filename "config"
    # use_multiple_files
    # set_filenames "default"

    # not possible to set primary_key like so:
    # self.primary_key = :name

    set_root_path "#{Pwb::Engine.root}/config/import_mappings"
    # set_filename "client_setups"
    use_multiple_files
    set_filenames "mls_interealty", "mls_mris"

  end
end
