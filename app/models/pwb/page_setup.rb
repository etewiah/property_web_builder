module Pwb
  # https://github.com/zilkey/active_hash
  class PageSetup < ActiveJSON::Base
    set_root_path "#{Pwb::Engine.root}/config/pwb/page_setups"
    use_multiple_files
    set_filenames "home","about-us","default"

    include ActiveHash::Associations
    has_many :pages, foreign_key: "setup_id", class_name: "Pwb::Page", primary_key: "id"

  end
end

