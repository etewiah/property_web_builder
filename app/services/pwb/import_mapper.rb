require 'rets'
module Pwb
  class ImportMapper
    attr_accessor :mls_mapping

    def initialize(mls_name)
      mls_mapping = Pwb::ImportMapping.find_by_name(mls_name)
      self.mls_mapping = mls_mapping
    end

    def map_property mls_property
      # mappings is a hash of MLS fieldnames and the equivalent fieldname in pwb
      mappings = mls_mapping.mappings

      # mapped_property_old = mls_property.to_hash.map {|k, v| [mappings[k], v] }.to_h
      # return mapped_property_old.except(nil)

      mapped_property = {}
      mappings.each do |mapping|
        mapped_property[mapping[1]["fieldName"]] = mls_property[mapping[0]].blank? ? mapping[1]["default"] : mls_property[mapping[0]]
      end

      # TODO - figure out way of importing extras
      return mapped_property
    end


  end
end
