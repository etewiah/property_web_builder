# frozen_string_literal: true

# Concern for tracking visitor analytics events
# Include in controllers that serve public-facing pages
#
# Usage:
#   class PropsController < ApplicationController
#     include Trackable
#
#     def show
#       @property = Pwb::ListedProperty.find(params[:id])
#       track_property_view(@property)
#     end
#   end
#
module Trackable
  extend ActiveSupport::Concern

  included do
    after_action :track_page_view, if: :should_track?
  end

  private

  # Automatically track page views on GET requests
  def track_page_view
    ahoy.track "page_viewed", page_view_properties
  end

  def page_view_properties
    {
      page_type: controller_name,
      action: action_name,
      path: request.path,
      page_title: content_for(:title) || controller_name.titleize
    }
  end

  # Track property listing views
  # Call this from your property show action
  def track_property_view(property)
    return unless property.present?

    ahoy.track "property_viewed", {
      property_id: property.id,
      property_reference: property.try(:reference),
      property_type: property_type_for(property),
      price: property.try(:price_cents),
      bedrooms: property.try(:bedrooms),
      bathrooms: property.try(:bathrooms),
      city: property.try(:city),
      region: property.try(:region)
    }.compact
  end

  # Track property search events
  def track_property_search(params, results_count)
    ahoy.track "property_searched", {
      query: params[:q],
      property_type: params[:property_type],
      min_price: params[:min_price],
      max_price: params[:max_price],
      bedrooms: params[:bedrooms],
      location: params[:location],
      results_count: results_count
    }.compact
  end

  # Track inquiry/contact form submissions
  def track_inquiry(message_or_contact, property: nil)
    ahoy.track "inquiry_submitted", {
      property_id: property&.id,
      source: params[:source] || "contact_form",
      has_phone: message_or_contact.try(:phone).present?,
      message_length: message_or_contact.try(:content)&.length
    }.compact
  end

  # Track contact form opens (call from JS or turbo action)
  def track_contact_form_opened(property: nil)
    ahoy.track "contact_form_opened", {
      property_id: property&.id,
      source: params[:source]
    }.compact
  end

  # Track property gallery/photo views
  def track_gallery_view(property)
    ahoy.track "gallery_viewed", {
      property_id: property.id
    }
  end

  # Track social shares
  def track_property_share(property, platform: nil)
    ahoy.track "property_shared", {
      property_id: property.id,
      platform: platform || params[:platform]
    }.compact
  end

  # Track favorites/saved properties
  def track_property_favorite(property, action: :add)
    ahoy.track "property_favorited", {
      property_id: property.id,
      action: action # :add or :remove
    }
  end

  # Determine if request should be tracked
  def should_track?
    return false unless request.get?
    return false if request.xhr?
    return false unless Pwb::Current.website.present?
    return false if admin_path?

    true
  end

  def admin_path?
    request.path.start_with?("/site_admin") ||
      request.path.start_with?("/admin") ||
      request.path.start_with?("/rails/")
  end

  def property_type_for(property)
    if property.respond_to?(:for_sale?) && property.for_sale?
      "sale"
    elsif property.respond_to?(:for_rent?) && property.for_rent?
      "rental"
    else
      "unknown"
    end
  end
end
