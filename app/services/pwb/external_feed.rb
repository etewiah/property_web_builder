# frozen_string_literal: true

module Pwb
  # ExternalFeed module provides integration with external property listing feeds.
  # This module contains providers, data normalization, caching, and error handling.
  #
  # Usage:
  #   # Get the feed manager for a website
  #   feed = website.external_feed
  #
  #   # Search for properties
  #   result = feed.search(listing_type: :sale, page: 1)
  #
  #   # Find a specific property
  #   property = feed.find("REF123")
  #
  module ExternalFeed
    # Ensure error classes are loaded when the module is accessed
    # This is necessary because the error classes are defined in a nested module
    # and then aliased at the ExternalFeed level
    require_dependency "pwb/external_feed/errors"
  end
end
