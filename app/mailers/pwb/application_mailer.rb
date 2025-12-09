# frozen_string_literal: true

module Pwb
  class ApplicationMailer < ActionMailer::Base
    # Default from address - can be overridden via DEFAULT_FROM_EMAIL env var
    # Format: "Name <email@example.com>" or just "email@example.com"
    default from: -> { default_from_address }

    layout "mailer"

    private

    def self.default_from_address
      ENV.fetch("DEFAULT_FROM_EMAIL") { "PropertyWebBuilder <noreply@propertywebbuilder.com>" }
    end

    def default_from_address
      self.class.default_from_address
    end
  end
end
