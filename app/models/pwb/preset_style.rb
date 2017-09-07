module Pwb
  # https://github.com/zilkey/active_hash
  class PresetStyle < ActiveJSON::Base
    set_root_path "#{Pwb::Engine.root}/config/preset_styles"
    use_multiple_files
    set_filenames "purple_teal"
    # , "green_light"

    def class_name element_name
      self[:associations][element_name] || ""
    end

    def self.default
      Pwb::PresetStyle.first
    end
  end
end
# purple teal
# $primary-color-dark:   #7B1FA2
# $primary-color:        #9C27B0
# $primary-color-light:  #E1BEE7
# $primary-color-text:   #FFFFFF
# $accent-color:         #009688
# $primary-text-color:   #212121
# $secondary-text-color: #757575
# $divider-color:        #BDBDBD