# frozen_string_literal: true

module ListedProperty
  # Provides localized title and description accessors for ListedProperty
  # Dynamically generates locale-specific methods (title_en, title_es, etc.)
  module Localizable
    extend ActiveSupport::Concern

    # Title is marketing text stored on the listing.
    # Checks sale_listing first, then rental_listing.
    # @return [String, nil] the title in current locale
    def title
      sale_listing&.title || rental_listing&.title
    end

    # Description is marketing text stored on the listing.
    # Checks sale_listing first, then rental_listing.
    # @return [String, nil] the description in current locale
    def description
      sale_listing&.description || rental_listing&.description
    end

    included do
      # Generate locale-specific accessors for all available locales
      # Creates methods like title_en, title_es, description_en, etc.
      I18n.available_locales.each do |locale|
        define_method("title_#{locale}") do
          sale_listing&.send("title_#{locale}") || rental_listing&.send("title_#{locale}")
        end

        define_method("description_#{locale}") do
          sale_listing&.send("description_#{locale}") || rental_listing&.send("description_#{locale}")
        end
      end
    end
  end
end
