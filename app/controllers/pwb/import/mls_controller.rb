# frozen_string_literal: true

# DEPRECATED: This controller is deprecated and non-functional.
# The RETS gem has been removed from the project (Dec 2024).
# MLS/RETS integration was experimental and never fully implemented.
# See docs/claude_thoughts/DEPRECATED_FEATURES.md for details.

module Pwb
  # @deprecated This controller is deprecated - RETS integration removed Dec 2024
  class Import::MlsController < ApplicationApiController
    # @deprecated RETS integration has been removed
    def retrieve
      %i[username password login_url mls_unique_name].each do |param_name|
        unless params[param_name].present?
          return render json: { error: "Please provide #{param_name}."}, status: 422
        end
      end
      mls_name = params[:mls_unique_name]
      # || "mris"
      import_source = Pwb::ImportSource.find_by_unique_name mls_name

      import_source.details[:username] = params[:username]
      import_source.details[:password] = params[:password]
      import_source.details[:login_url] = params[:login_url]

      limit = 25
      properties = Pwb::MlsConnector.new(import_source).retrieve("(ListPrice=0+)", limit)
      retrieved_properties = []
      count = 0
      # return render json: properties.as_json

      properties.each do |property|
        if count < 100
          mapped_property = ImportMapper.new(import_source.import_mapper_name).map_property(property)
          retrieved_properties.push mapped_property
        end
        count += 1
      end

      render json: retrieved_properties
    end
  end
end
