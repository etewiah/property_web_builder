module Pwb
  class Theme <  ActiveJSON::Base
    set_root_path "#{Pwb::Engine.root}/app/themes"
    set_filename "config"
    # use_multiple_files
    # set_filenames "default"

    include ActiveHash::Associations
    has_one :agency, :foreign_key => "site_template_id", :class_name => "Pwb::Agency"

  end
end
