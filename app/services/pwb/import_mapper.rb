require 'rets'
module Pwb
  class ImportMapper
    attr_accessor :mls_mapping

    def initialize(mls_name)
      mls_mapping = Pwb::ImportMapping.find_by_name(mls_name)
      self.mls_mapping = mls_mapping
    end

    def map_property mls_property
      mappings = mls_mapping.mappings
      mapped_property = mls_property.to_hash.map {|k, v| [mappings[k], v] }.to_h

      return mapped_property.except(nil)
    end


  end
end
