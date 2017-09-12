module Pwb
  # https://github.com/zilkey/active_hash
  class PageSetup < ActiveJSON::Base
    set_root_path "#{Pwb::Engine.root}/config/pwb/page_setups"
    use_multiple_files
    set_filenames "home","about-us"
    # , "green_light"

    # def class_name element_name
    #   self[:associations][element_name] || ""
    # end

    # def self.default_values
    #   Pwb::PageSetup.first.attributes.as_json
    # end

    include ActiveHash::Associations
    has_one :page, foreign_key: "slug", class_name: "Pwb::Page", primary_key: "name"

  end
end

