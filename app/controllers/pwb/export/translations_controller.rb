module Pwb
  class Export::TranslationsController < ApplicationApiController
    # http://localhost:3000/export/translations/all
    def all
      # render plain: I18n::Backend::ActiveRecord::Translation.to_csv
      # send_data text: I18n::Backend::ActiveRecord::Translation.to_csv
      # above results in below message in chrome:
      # Resource interpreted as Document but transferred with MIME type application/octet-stream

      translations = I18n::Backend::ActiveRecord::Translation.where(id: [1, 2, 3])
      @header_cols = ["translation-id", "key", "value", "locale"]
      @translation_fields = %i[id key value locale]
      @translations_array = []
      translations.each do |translation|
        translation_field_values = []
        @translation_fields.each do |field|
          # for each of the translation_fields
          # get its value for the current translation
          translation_field_values << (translation.send field)
          # translation[field] would work instead of "translation.send field" in most
          # cases but not for title_es and associated fields
        end
        @translations_array << translation_field_values
      end
      headers['Content-Disposition'] = "attachment; filename=\"pwb-translations.csv\""
      headers['Content-Type'] ||= 'text/csv'
      render "all.csv"
    end
  end
end
