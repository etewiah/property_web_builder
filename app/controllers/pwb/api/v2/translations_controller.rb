require_dependency "pwb/application_controller"

module Pwb
  class Api::V2::TranslationsController < ApplicationApiController
    # protect_from_forgery with: :null_session

    respond_to :json

    def update
      params[:i18nKey]
      params[:changes]
      # updated_phrases = []

      params[:changes].keys.each do |locale|
        phrase = I18n::Backend::ActiveRecord::Translation.where(key: params[:i18nKey], locale: locale).first
        phrase.value = params[:changes][locale]
        phrase.save!
        # updated_phrases.push phrase
      end
      # I18n.backend.reload!
      # above will ensure that calls like I18n.t("extras") in list above will
      # have updated value.  There might be a more refined way to refresh that I don't know about

      key_phrases = I18n::Backend::ActiveRecord::Translation.where(key: params[:i18nKey])

      return render json: key_phrases.to_json
    end

    # return translations for all locales
    # for a given batch_key
    def get_by_batch
      # TODO: make use of params[:locales] to limit
      # data returned to those locales
      batch_key = params[:batch_key]
      # prefix = ""
      translation_keys = []
      translation_keys = FieldKey.where(tag: params[:batch_key]).visible.pluck("global_key")

      # translations = I18n::Backend::ActiveRecord::Translation.where("key IN (?)", translation_keys)
      translation_groups = I18n::Backend::ActiveRecord::Translation.lookup(translation_keys).group_by { |translation|  translation.key}

      sortable_translations = []
      translation_keys.each do |translation_key|
        sortable_translations.push({
          key: translation_key,
          translations: translation_groups[translation_key]
        })
      end

      render json: {
        translations: sortable_translations.as_json,
        batch_key: batch_key
      }
    end

  end
end
