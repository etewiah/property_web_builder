module Pwb
  # https://github.com/zilkey/active_hash
  class ImportMapping < ActiveJSON::Base
    # set_filename "config"
    # not possible to set primary_key like so:
    # self.primary_key = :name

    set_root_path "#{Pwb::Engine.root}/config/import_mappings"
    use_multiple_files
    # when adding new files, need to restart server and ensure correct name 
    # is used in corresponding json file
    set_filenames "mls_interealty", "mls_mris", "mls_csv_jon", "mls_olr"

  end
end
