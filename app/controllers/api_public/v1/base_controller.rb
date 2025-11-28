module ApiPublic
  module V1
    class BaseController < ActionController::Base
      include SubdomainTenant
      skip_before_action :verify_authenticity_token
    end
  end
end
