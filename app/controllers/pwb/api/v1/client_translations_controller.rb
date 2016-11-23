require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::ClientTranslationsController < ApplicationController
    respond_to :json

    def index
      locale = params[:locale]

      phrases = I18n::Backend::ActiveRecord::Translation.where(:locale => locale)
      render :json => {
        locale =>  phrases.as_json(:only => ["i18n_key","i18n_value"])
      }
    end

  end
end
