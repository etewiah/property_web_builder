# frozen_string_literal: true

# LocalizedSerializer
#
# Provides helper methods for serializing translated attributes dynamically
# based on Pwb::Config::BASE_LOCALES.
#
# Usage:
#   class Api::V1::PropertiesController < ApplicationController
#     include LocalizedSerializer
#
#     def serialize_property_data(property)
#       {
#         id: property.id.to_s,
#         attributes: serialize_translated_attributes(property, :title, :description)
#       }
#     end
#   end
#
# This eliminates hardcoded locale fields like "title-en", "title-es", etc.
#
module LocalizedSerializer
  extend ActiveSupport::Concern

  # Serialize multiple translated attributes for an object
  #
  # @param object [Object] The object with translated attributes
  # @param attributes [Array<Symbol>] The attribute names to serialize
  # @return [Hash] Hash with all locale variants of each attribute
  #
  # @example
  #   serialize_translated_attributes(property, :title, :description)
  #   # => {
  #   #      "title-en" => "Beach House",
  #   #      "title-es" => "Casa de Playa",
  #   #      "description-en" => "Beautiful...",
  #   #      "description-es" => "Hermosa...",
  #   #      ...
  #   #    }
  #
  def serialize_translated_attributes(object, *attributes)
    result = {}

    Pwb::Config::BASE_LOCALES.each do |locale|
      locale_str = locale.to_s

      attributes.each do |attr|
        key = "#{attr}-#{locale_str}"
        accessor = "#{attr}_#{locale_str}"

        # Use send to call the locale accessor (e.g., title_en, description_es)
        result[key] = object.respond_to?(accessor) ? object.send(accessor) : nil
      end
    end

    result
  end

  # Serialize a single translated attribute for an object
  #
  # @param object [Object] The object with translated attribute
  # @param attribute [Symbol] The attribute name
  # @return [Hash] Hash with all locale variants
  #
  def serialize_translated_attribute(object, attribute)
    serialize_translated_attributes(object, attribute)
  end

  # Get the current translation for an attribute based on I18n.locale
  #
  # @param object [Object] The object with translated attribute
  # @param attribute [Symbol] The attribute name
  # @return [String, nil] The translation for current locale
  #
  def current_translation(object, attribute)
    locale_str = I18n.locale.to_s
    accessor = "#{attribute}_#{locale_str}"
    object.respond_to?(accessor) ? object.send(accessor) : nil
  end
end
