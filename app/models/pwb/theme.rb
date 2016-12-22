module Pwb
  class Theme <  ActiveJSON::Base
    set_root_path "#{Pwb::Engine.root}/app/themes"
    set_filename "config"
    # use_multiple_files
    # set_filenames "default"

    # not possible to set primary_key like so:
    # self.primary_key = :name

    include ActiveHash::Associations
    has_one :agency, foreign_key: "theme_name", class_name: "Pwb::Agency", primary_key: "name"

  end
end
