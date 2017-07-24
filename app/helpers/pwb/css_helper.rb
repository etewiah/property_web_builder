module Pwb
  module CssHelper

    def custom_styles(theme_name)
      render :partial => "pwb/custom_css/#{theme_name}", :locals => {}, formats: :css
    end

  end
end
