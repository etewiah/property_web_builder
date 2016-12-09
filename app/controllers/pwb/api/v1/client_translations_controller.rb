require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::ClientTranslationsController < ApplicationController

    protect_from_forgery with: :null_session

    respond_to :json

    def index
      # return all translations for a given locale
      # TODO - filter to subset needed by client ui
      locale = params[:locale]
      phrases = I18n::Backend::ActiveRecord::Translation.where(:locale => locale)
      render :json => {
        locale =>  phrases.as_json(:only => ["i18n_key","i18n_value"])
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
      return render json: {
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
      return render json: { success: true }
    end

    # # below called for completely new translations
    def create_translation_value
      batch_key = params[:batch_key]
      # batch_key might be "extra" or ..
      i18n_key = params[:i18n_key].sub(/^[.]*/,"")
      # regex above just incase there is a leading .
      subdomain = request.subdomain.downcase

      # http://stackoverflow.com/questions/5917355/find-or-create-race-conditions
      begin
        field_key = FieldKey.find_or_initialize_by(global_key: i18n_key)
        field_key.tag = batch_key
        field_key.save!
      rescue ActiveRecord::StatementInvalid => error
        @save_retry_count =  (@save_retry_count || 5)
        retry if( (@save_retry_count -= 1) > 0 )
        raise error
      end
      phrase = I18n::Backend::ActiveRecord::Translation.find_or_create_by(
        :key => i18n_key,
      :locale => params[:locale])
      phrase.value = params[:i18n_value]
      if phrase.save!
        return render json: { success: true }
      else
        return render json: { error: "unable to create phrase" }
      end
    end


    # def add_locale_translation
    #   field_key = FieldKey.find_by_global_key(params[:i18n_key])
    #   phrase = I18n::Backend::ActiveRecord::Translation.find_or_create_by(
    #     :key => field_key.global_key,
    #   :locale => params[:locale])
    #   unless phrase.value.present?
    #     phrase.value = params[:i18n_value]
    #     phrase.save!
    #   end
    #   return render json: { success: true }
    # end




  end
end
