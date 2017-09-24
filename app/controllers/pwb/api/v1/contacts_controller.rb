module Pwb
  class Api::V1::ContactsController < ApplicationApiController

    respond_to :json

    def index
      contacts = Pwb::Contact.all
      return render json:         contacts.as_json
      # # Globalize.fallbacks = {:ru => [:en]}
      # # top_nav_links, footer_links = nil
      # locale = params[:locale] || :en
      # I18n.with_locale(locale) do
      #   top_nav_links = Link.ordered_top_nav
      #   footer_links = Link.ordered_footer
      #   render json: {
      #     footer_links: footer_links.as_json,
      #     top_nav_links: top_nav_links.as_json
      #   }
      # end
    end

    private

  end
end
