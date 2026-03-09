# frozen_string_literal: true

module LocalhostDefaultWebsite
  extend ActiveSupport::Concern

  private

  def localhost_default_website
    return unless localhost_root_request?

    Pwb::Website.find_by_subdomain('default')
  end

  def localhost_root_request?
    request.subdomain.blank? && %w[localhost 127.0.0.1 0.0.0.0].include?(request.host.to_s.downcase)
  end
end