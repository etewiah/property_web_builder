require 'rets'
require 'faraday'

module Pwb
  class MlsConnector
    attr_accessor :import_source

    def initialize(import_source)
      self.import_source = import_source
    end

    def retrieve(query, limit)
      unless import_source.source_type == "rets"
        raise ArgumentError, "Unsupported source type: #{import_source.source_type}. Only RETS is supported."
      end

      retrieve_via_rets(query, limit)
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
