require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::TranslationsController < ApplicationApiController
    protect_from_forgery with: :null_session

    respond_to :json

    def list
      # return all admin ui translations for a given locale

      # start by ensuring that new translations get loaded
      # I18n.backend.reload!
      # - makes more sense to call above after each update

      locale = params[:locale]
      # below are phrases like webContentLabels which are not managed by admin:
      phrases = I18n.t("admin", locale: locale, default: {})
      # below are phrases such as extras & propertyTypes which can be
      # managed by admin and so are in db:
      phrases[:extras] = I18n.t("extras", locale: locale, default: {})
      phrases[:propertyStates] = I18n.t("propertyStates", locale: locale, default: {})
      phrases[:propertyTypes] = I18n.t("propertyTypes", locale: locale, default: {})
      phrases[:propertyOrigin] = I18n.t("propertyOrigin", locale: locale, default: {})
      phrases[:propertyLabels] = I18n.t("propertyLabels", locale: locale, default: {})
      # .limit(2)
      render json: {
        locale => phrases
        # locale =>  phrases.as_json(:only => ["i18n_key","i18n_value"])
      }
    end

    def get_by_batch
      # return all translations for all locales
      # for a given batch_key
      batch_key = params[:batch_key]
      # prefix = ""
      translation_keys = []
      translation_keys = FieldKey.where(tag: params[:batch_key]).visible.pluck("global_key")

      translations = I18n::Backend::ActiveRecord::Translation.where("key IN (?)", translation_keys)
      render json: {
        translations: translations.as_json,
        batch_key: batch_key
      }
    end

    # deletes the field_key referencing the translation
    def delete_translation_values
      field_key = FieldKey.find_by_global_key(params[:i18n_key])
      field_key.visible = false

      # not convinced it makes sense to delete the associated translations
      # phrases = I18n::Backend::ActiveRecord::Translation.where(:key => params[:i18n_key])
      # phrases.destroy_all

      field_key.save!
      render json: { success: true }
    end

    # # below called for completely new set of translations
    def create_translation_value
      batch_key = params[:batch_key]
      # batch_key might be "extra" or ..
      i18n_key = params[:i18n_key].sub(/^[.]*/, "")
      # regex above just incase there is a leading .
      full_i18n_key = batch_key.underscore.camelcase(:lower) + "." + i18n_key
      # eg propertyTypes.flat
      # subdomain = request.subdomain.downcase

      # http://stackoverflow.com/questions/5917355/find-or-create-race-conditions
      begin
        field_key = FieldKey.find_or_initialize_by(global_key: full_i18n_key)
        field_key.tag = batch_key
        field_key.save!
      rescue ActiveRecord::StatementInvalid => error
        @save_retry_count = (@save_retry_count || 5)
        retry if (@save_retry_count -= 1) > 0
        raise error
      end
      phrase = I18n::Backend::ActiveRecord::Translation.find_or_create_by(
        key: full_i18n_key,
      locale: params[:locale]
)
      phrase.value = params[:i18n_value]
      if phrase.save!
        I18n.backend.reload!
        return render json: { success: true }
      else
        return render json: { error: "unable to create phrase" }
      end
    end

    def update_for_locale
      phrase = I18n::Backend::ActiveRecord::Translation.find(params[:id])
      phrase.value = params[:i18n_value]

      if phrase.save!
        I18n.backend.reload!
        # above will ensure that calls like I18n.t("extras") in list above will
        # have updated value.  There might be a more refined way to refresh that I don't know about
        return render json: phrase.to_json
      else
        return render json: { error: "unable to update phrase" }
      end
    end

    # below for adding new locale to an existing translation
    def create_for_locale
      field_key = FieldKey.find_by_global_key(params[:i18n_key])
      phrase = I18n::Backend::ActiveRecord::Translation.find_or_create_by(
        key: field_key.global_key,
      locale: params[:locale]
)
      unless phrase.value.present?
        I18n.backend.reload!
        phrase.value = params[:i18n_value]
        phrase.save!
      end
      render json: { success: true }
    end
  end
end
