# frozen_string_literal: true

# RobotsController generates dynamic robots.txt per tenant
# Includes sitemap reference and crawling directives
class RobotsController < ActionController::Base
  include SubdomainTenant

  # Tenant is set automatically via SubdomainTenant concern

  def index
    @website = Pwb::Current.website
    @host = "#{request.protocol}#{request.host_with_port}"

    respond_to do |format|
      format.text { render layout: false }
    end
  end
end
