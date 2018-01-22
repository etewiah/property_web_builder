require 'rets'
require 'faraday'
require 'ruby_odata'

module Pwb
  class MlsConnector
    attr_accessor :import_source

    def initialize(import_source)
      self.import_source = import_source
    end

    def retrieve query, limit
      if import_source.source_type == "odata"
        properties = retrieve_via_odata query, limit
      else
        properties = retrieve_via_rets query, limit
      end
    end

    def retrieve_via_odata query, limit
      # conn = Faraday.new(:url => 'http://dmm-api.olrdev.com/Service.svc') do |faraday|
      #   faraday.basic_auth('', '')
      #   faraday.request  :url_encoded             # form-encode POST params
      #   faraday.response :logger                  # log requests to STDOUT
      #   faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      # end
      # response = conn.get "/Listings()?$filter=RentalListingType%20ge%200L"
      # response.body

      svc = OData::Service.new import_source.details[:login_url],
        { username: import_source.details[:username],
          password: import_source.details[:password]
        }

      svc.Listings.expand('Building')
      listings = svc.execute
      return JSON.parse(listings.to_json)
    end

    def retrieve_via_rets query, limit
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

      return properties
    end

  end
end
