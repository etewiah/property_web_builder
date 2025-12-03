module Pwb
  # https://github.com/zilkey/active_hash
  class Theme < ActiveJSON::Base
    set_root_path "#{Rails.root}/app/themes"
    set_filename "config"
    # use_multiple_files
    # set_filenames "default"

    # not possible to set primary_key like so:
    # self.primary_key = :name

    include ActiveHash::Associations
    # has_one :agency, foreign_key: "theme_name", class_name: "Pwb::Agency", primary_key: "name"
    has_one :website, foreign_key: "theme_name", class_name: "Pwb::Website", primary_key: "name"

    # Check if this theme has a custom template for a given page part
    def has_custom_template?(page_part_key)
      File.exist?(Rails.root.join("app/themes/#{name}/page_parts/#{page_part_key}.liquid"))
    end
  end
end
