# frozen_string_literal: true

module Pwb
  # Service for handling signup API operations
  # This service is called by the API endpoints and handles all business logic
  # for creating users, websites, and managing the provisioning process.
  #
  # Uses token-based tracking instead of sessions to support cross-domain API calls.
  #
  class SignupApiService
    class SignupError < StandardError; end

    TOKEN_EXPIRY = 24.hours

    # Start the signup process
    # Creates a lead user, reserves a subdomain, and generates a signup token
    #
    # @param email [String] User's email address
    # @return [Hash] { success: true, user: User, subdomain: Subdomain, signup_token: String } or { success: false, errors: [] }
    #
    def start_signup(email:)
      email = email.to_s.strip.downcase

      ActiveRecord::Base.transaction do
        # Check if user already exists
        user = Pwb::User.find_by(email: email)

        if user
          # User exists - check if they have an incomplete signup
          if user.websites.empty?
            # Check if they already have a reserved subdomain
            existing_subdomain = Pwb::Subdomain.find_by(reserved_by_email: email, aasm_state: 'reserved')

            # Generate new signup token for this user
            token = generate_signup_token(user)

            if existing_subdomain
              return { success: true, user: user, subdomain: existing_subdomain, signup_token: token }
            end

            # Reserve a new subdomain for continuation
            subdomain = reserve_subdomain_for_user(email)
            return { success: true, user: user, subdomain: subdomain, signup_token: token }
          else
            # User already has a website
            return { success: false, errors: ["An account with this email already exists. Please sign in."] }
          end
        end

        # Create new lead user (skip validations since website will be assigned later)
        user = Pwb::User.new(
          email: email,
          password: SecureRandom.hex(16), # Temporary password
          confirmed_at: Time.current # Auto-confirm for signup flow
        )

        unless user.save(validate: false)
          return { success: false, errors: user.errors.full_messages }
        end

        # Generate signup token
        token = generate_signup_token(user)

        # Reserve a subdomain for this user
        subdomain = reserve_subdomain_for_user(email)

        { success: true, user: user, subdomain: subdomain, signup_token: token }
      end
    rescue StandardError => e
      Rails.logger.error "[SignupApiService] start_signup error: #{e.message}"
      { success: false, errors: [e.message] }
    end

    # Find user by signup token
    # Returns nil if token is invalid or expired
    #
    # @param token [String] The signup token
    # @return [Pwb::User, nil]
    #
    def find_user_by_token(token)
      return nil if token.blank?

      user = Pwb::User.find_by(signup_token: token)
      return nil unless user
      return nil if user.signup_token_expires_at && user.signup_token_expires_at < Time.current

      user
    end

    # Configure the website
    # Creates a website record with the chosen subdomain and site type
    #
    # @param user [Pwb::User] The user from step 1
    # @param subdomain_name [String] Chosen subdomain
    # @param site_type [String] Type of site
    # @return [Hash] { success: true, website: Website } or { success: false, errors: [] }
    #
    def configure_site(user:, subdomain_name:, site_type:)
      subdomain_name = subdomain_name.to_s.strip.downcase

      # Validate subdomain
      validation = SubdomainGenerator.validate_custom_name(subdomain_name, reserved_by_email: user.email)
      unless validation[:valid]
        return { success: false, errors: validation[:errors].map { |e| "Subdomain #{e}" } }
      end

      # Validate site type
      valid_site_types = %w[residential commercial vacation_rental]
      unless valid_site_types.include?(site_type)
        return { success: false, errors: ["Invalid site type"] }
      end

      ActiveRecord::Base.transaction do
        # Check if subdomain is taken by an existing website
        if Pwb::Website.exists?(subdomain: subdomain_name)
          return { success: false, errors: ["This subdomain is already taken"] }
        end

        # Create the website
        website = Pwb::Website.new(
          subdomain: subdomain_name,
          site_type: site_type,
          provisioning_state: 'subdomain_allocated'
        )

        unless website.save
          return { success: false, errors: website.errors.full_messages }
        end

        # Associate user with website as admin
        create_website_admin(user: user, website: website)

        { success: true, website: website }
      end
    rescue StandardError => e
      Rails.logger.error "[SignupApiService] configure_site error: #{e.message}"
      { success: false, errors: [e.message] }
    end

    # Provision the website
    # Runs the seeding and configuration process
    #
    # @param website [Pwb::Website] The website to provision
    # @return [Hash] { success: true } or { success: false, errors: [] }
    #
    def provision_website(website:)
      return { success: true } if website.live?

      begin
        # Use the existing provisioning service
        service = Pwb::ProvisioningService.new
        result = service.provision_website(website: website)

        if result[:success]
          { success: true }
        else
          { success: false, errors: result[:errors] || ["Provisioning failed"] }
        end
      rescue StandardError => e
        Rails.logger.error "[SignupApiService] provision_website error: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")

        website.update(
          provisioning_state: 'failed',
          provisioning_error: e.message
        )

        { success: false, errors: [e.message] }
      end
    end

    private

    # Generate a unique signup token for a user
    # Uses update_columns to skip validations (user may not have website yet)
    #
    # @param user [Pwb::User] The user to generate token for
    # @return [String] The generated token
    #
    def generate_signup_token(user)
      token = SecureRandom.urlsafe_base64(32)
      user.update_columns(
        signup_token: token,
        signup_token_expires_at: TOKEN_EXPIRY.from_now
      )
      token
    end

    # Reserve a subdomain for a user during signup
    # Creates a Subdomain record in 'reserved' state
    #
    # @param email [String] User's email
    # @return [Pwb::Subdomain] The reserved subdomain
    #
    def reserve_subdomain_for_user(email)
      # Use the class method if available, otherwise create directly
      result = Pwb::Subdomain.reserve_for_email(email, duration: 24.hours)

      if result[:subdomain]
        result[:subdomain]
      else
        # Fallback: generate and create directly
        subdomain_name = SubdomainGenerator.generate
        Pwb::Subdomain.create!(
          name: subdomain_name,
          aasm_state: 'reserved',
          reserved_by_email: email,
          reserved_at: Time.current,
          reserved_until: 24.hours.from_now
        )
      end
    end

    def create_website_admin(user:, website:)
      # Create user membership with admin role
      membership = Pwb::UserMembership.new(
        user: user,
        website: website,
        role: 'admin',
        active: true
      )

      unless membership.save
        raise SignupError, "Failed to create website admin: #{membership.errors.full_messages.join(', ')}"
      end

      # Also associate user's primary website if not set
      user.update!(website: website) if user.website_id.nil?

      membership
    end
  end
end
