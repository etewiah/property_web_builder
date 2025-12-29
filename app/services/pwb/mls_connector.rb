# frozen_string_literal: true

# DEPRECATED: This file is deprecated and will be removed in a future version.
# The RETS gem has been removed from the project (Dec 2024).
# MLS/RETS integration was experimental and never fully implemented.
# See docs/claude_thoughts/DEPRECATED_FEATURES.md for details.
#
# If you need MLS integration, consider:
# - Using a third-party MLS API service
# - Implementing a custom CSV/XML import solution
# - Using property data aggregation services

# require 'rets'  # REMOVED - gem no longer available
require 'faraday'

module Pwb
  # @deprecated This class is deprecated and non-functional without the rets gem.
  class MlsConnector
    attr_accessor :import_source

    def initialize(import_source)
      self.import_source = import_source
    end

    def retrieve(query, limit)
      raise NotImplementedError, <<~MSG
        DEPRECATED: MLS/RETS integration has been removed (Dec 2024).
        The rets gem is no longer included in this project.
        See docs/claude_thoughts/DEPRECATED_FEATURES.md for alternatives.
      MSG
    end

    private

    def retrieve_via_rets(query, limit)
      client = Rets::Client.new(import_source.details)

      # $ver = "RETS/1.7.2";
      # $user_agent = "RETS Test/1.0";
      quantity = :all
      # quantity has to be one of :first or :all
      # but would rather use limit than :first
      properties = client.find quantity, {
        search_type: 'Property',
        class: import_source.default_property_class,
        query: query,
        limit: limit
      }
      # photos = client.objects '*', {
      #   resource: 'Property',
      #   object_type: 'Photo',
      #   resource_id: '242502823'
      # }

      properties
    end
  end
end
