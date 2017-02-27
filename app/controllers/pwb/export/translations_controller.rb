module Pwb
  class Export::TranslationsController < ApplicationApiController

    # http://localhost:3000/export/translations/all
    def all
      # render plain: I18n::Backend::ActiveRecord::Translation.to_csv

      send_data text: I18n::Backend::ActiveRecord::Translation.to_csv
      # above results in below message in chrome:
      # Resource interpreted as Document but transferred with MIME type application/octet-stream
    end

  end
end
