# frozen_string_literal: true

module Api
  module Signup
    # SubdomainOperations
    #
    # Handles subdomain-related operations for signup API:
    # - check_subdomain: Check subdomain availability
    # - suggest_subdomain: Get random subdomain suggestion
    # - lookup_subdomain: Look up subdomain by email
    #
    module SubdomainOperations
      extend ActiveSupport::Concern

      # GET /api/signup/check_subdomain
      # Check if a subdomain is available
      #
      def check_subdomain
        name = params[:name]&.strip&.downcase
        email = current_signup_email

        result = Pwb::SubdomainGenerator.validate_custom_name(name, reserved_by_email: email)

        json_response(
          available: result[:valid],
          normalized: result[:normalized],
          errors: result[:errors]
        )
      end

      # GET /api/signup/suggest_subdomain
      # Get a random available subdomain from the pool
      #
      def suggest_subdomain
        subdomain = random_available_subdomain

        if subdomain
          json_response(subdomain: subdomain.name)
        else
          json_response(subdomain: Pwb::SubdomainGenerator.generate)
        end
      end

      # GET /api/signup/lookup_subdomain
      # Look up the full subdomain for a user by email
      #
      def lookup_subdomain
        email = params[:email]&.strip&.downcase

        if email.blank? || !valid_email?(email)
          return error_response("Please provide a valid email address", status: :bad_request)
        end

        result = find_subdomain_for_email(email)

        if result
          success_response(**result)
        else
          error_response("No subdomain found for this email address", status: :not_found)
        end
      end

      private

      def current_signup_email
        return nil unless session[:signup_user_id]

        Pwb::User.find_by(id: session[:signup_user_id])&.email
      end

      def random_available_subdomain
        Pwb::Subdomain
          .available
          .where.not(name: Pwb::Website.select(:subdomain))
          .order('RANDOM()')
          .first
      end

      def valid_email?(email)
        email.match?(URI::MailTo::EMAIL_REGEXP)
      end

      def find_subdomain_for_email(email)
        # First check for a user with a website
        user = Pwb::User.find_by(email: email)
        if user
          website = user.websites.first
          return build_website_lookup_response(email, website) if website
        end

        # Check for a reserved subdomain (signup in progress)
        reserved = Pwb::Subdomain.find_by(reserved_by_email: email, aasm_state: 'reserved')
        return build_reserved_lookup_response(email, reserved) if reserved

        nil
      end

      def build_website_lookup_response(email, website)
        {
          email: email,
          subdomain: website.subdomain,
          full_subdomain: full_subdomain_for(website.subdomain),
          website_live: website.live?,
          website_url: website.live? ? website.primary_url : nil
        }
      end

      def build_reserved_lookup_response(email, subdomain)
        {
          email: email,
          subdomain: subdomain.name,
          full_subdomain: full_subdomain_for(subdomain.name),
          website_live: false,
          status: 'reserved',
          message: 'Subdomain is reserved but website not yet provisioned'
        }
      end

      def full_subdomain_for(name)
        base_domain = ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
        "#{name}.#{base_domain}"
      end
    end
  end
end
