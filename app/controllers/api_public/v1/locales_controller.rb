# frozen_string_literal: true

module ApiPublic
  module V1
    # Public API endpoint for available locales/languages
    # Returns enabled locales for the current website for language switchers and hreflang
    class LocalesController < BaseController
      # GET /api_public/v1/locales
      def index
        website = Pwb::Current.website

        render json: {
          default_locale: default_locale(website),
          available_locales: available_locales(website),
          current_locale: I18n.locale.to_s
        }
      end

      private

      def default_locale(website)
        if website.respond_to?(:default_locale) && website.default_locale.present?
          website.default_locale
        else
          I18n.default_locale.to_s
        end
      end

      def available_locales(website)
        # Website may have enabled_locales field, otherwise fall back to app defaults
        locales = if website.respond_to?(:enabled_locales) && website.enabled_locales.present?
                    website.enabled_locales
                  else
                    %w[en es de fr nl pt it]
                  end

        locales.map do |code|
          {
            code: code,
            name: locale_name(code),
            native_name: locale_native_name(code),
            flag_emoji: locale_flag(code),
            url_prefix: code == default_locale(website) ? nil : "/#{code}"
          }
        end
      end

      def locale_name(code)
        LOCALE_NAMES[code] || code.upcase
      end

      def locale_native_name(code)
        LOCALE_NATIVE_NAMES[code] || code.upcase
      end

      def locale_flag(code)
        LOCALE_FLAGS[code] || "🏳️"
      end

      LOCALE_NAMES = {
        "en" => "English",
        "es" => "Spanish",
        "de" => "German",
        "fr" => "French",
        "nl" => "Dutch",
        "pt" => "Portuguese",
        "it" => "Italian",
        "ru" => "Russian",
        "zh" => "Chinese",
        "ja" => "Japanese",
        "ar" => "Arabic",
        "pl" => "Polish",
        "sv" => "Swedish",
        "no" => "Norwegian",
        "da" => "Danish",
        "fi" => "Finnish"
      }.freeze

      LOCALE_NATIVE_NAMES = {
        "en" => "English",
        "es" => "Español",
        "de" => "Deutsch",
        "fr" => "Français",
        "nl" => "Nederlands",
        "pt" => "Português",
        "it" => "Italiano",
        "ru" => "Русский",
        "zh" => "中文",
        "ja" => "日本語",
        "ar" => "العربية",
        "pl" => "Polski",
        "sv" => "Svenska",
        "no" => "Norsk",
        "da" => "Dansk",
        "fi" => "Suomi"
      }.freeze

      LOCALE_FLAGS = {
        "en" => "🇬🇧",
        "es" => "🇪🇸",
        "de" => "🇩🇪",
        "fr" => "🇫🇷",
        "nl" => "🇳🇱",
        "pt" => "🇵🇹",
        "it" => "🇮🇹",
        "ru" => "🇷🇺",
        "zh" => "🇨🇳",
        "ja" => "🇯🇵",
        "ar" => "🇸🇦",
        "pl" => "🇵🇱",
        "sv" => "🇸🇪",
        "no" => "🇳🇴",
        "da" => "🇩🇰",
        "fi" => "🇫🇮"
      }.freeze
    end
  end
end
