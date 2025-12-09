module Pwb
  # Orchestrates the complete tenant provisioning workflow.
  # Handles the flow from user signup to fully provisioned website.
  #
  # Usage:
  #   service = Pwb::ProvisioningService.new
  #   result = service.start_signup(email: "user@example.com")
  #   result = service.configure_site(user: user, subdomain: "my-agency", site_type: "residential")
  #   result = service.provision_website(website: website)
  #
  class ProvisioningService
    class ProvisioningError < StandardError; end

    attr_reader :errors

    def initialize
      @errors = []
    end

    # Step 1: Start signup - create lead user and reserve subdomain
    def start_signup(email:)
      @errors = []

      ActiveRecord::Base.transaction do
        # Check if user already exists
        existing_user = User.find_by(email: email.downcase.strip)
        if existing_user
          if existing_user.active?
            @errors << "An account with this email already exists"
            return failure_result
          else
            # Reactivate churned user
            existing_user.reactivate! if existing_user.churned?
            return success_result(user: existing_user, subdomain: find_reserved_subdomain(email))
          end
        end

        # Create lead user (no password yet - just email capture)
        user = User.new(
          email: email.downcase.strip,
          password: SecureRandom.hex(16), # Temporary password
          onboarding_state: 'lead'
        )

        unless user.save(validate: false) # Skip validations for lead
          @errors.concat(user.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        # Reserve a subdomain for this email
        subdomain = Subdomain.reserve_for_email(email, duration: 10.minutes)
        unless subdomain
          @errors << "Unable to reserve a subdomain. Please try again."
          raise ActiveRecord::Rollback
        end

        success_result(user: user, subdomain: subdomain)
      end
    rescue StandardError => e
      @errors << e.message
      failure_result
    end

    # Step 2: Verify email (called when user clicks verification link)
    def verify_email(user:, token:)
      @errors = []

      # In a real implementation, verify the token
      # For now, just transition the state
      if user.may_verify_email?
        user.verify_email!
        success_result(user: user)
      else
        @errors << "Unable to verify email in current state"
        failure_result
      end
    end

    # Step 3: Configure site - set subdomain and site type
    def configure_site(user:, subdomain_name:, site_type:)
      @errors = []

      # Validate subdomain first (outside transaction)
      # Pass user's email so their reserved subdomain is allowed
      validation = SubdomainGenerator.validate_custom_name(subdomain_name, reserved_by_email: user.email)
      unless validation[:valid]
        @errors.concat(validation[:errors].map { |e| "Subdomain #{e}" })
        return failure_result
      end

      # Validate site type
      unless Website::SITE_TYPES.include?(site_type)
        @errors << "Invalid site type. Choose from: #{Website::SITE_TYPES.join(', ')}"
        return failure_result
      end

      result = nil
      ActiveRecord::Base.transaction do
        # Start onboarding if not already
        user.start_onboarding! if user.may_start_onboarding?

        # Create the website
        website = Website.new(
          subdomain: validation[:normalized],
          site_type: site_type,
          provisioning_state: 'pending',
          seed_pack_name: seed_pack_for_site_type(site_type)
        )

        unless website.save
          @errors.concat(website.errors.full_messages)
          raise ActiveRecord::Rollback
        end

        # Allocate subdomain to website
        pool_subdomain = Subdomain.find_by(name: validation[:normalized])
        if pool_subdomain
          pool_subdomain.allocate!(website) if pool_subdomain.may_allocate?
        end

        # Create owner membership
        membership = UserMembership.create!(
          user: user,
          website: website,
          role: 'owner',
          active: true
        )

        # Update user's primary website
        user.update!(website: website)
        user.update!(onboarding_step: 3)

        # Transition website state
        website.allocate_subdomain!

        result = success_result(user: user, website: website, membership: membership)
      end

      result || failure_result
    rescue StandardError => e
      @errors << e.message
      failure_result
    end

    # Step 4: Provision website - run seeding and configuration
    # Optionally pass a block to receive progress updates
    def provision_website(website:, &progress_block)
      @errors = []

      begin
        # Start configuring
        website.start_configuring!
        report_progress(progress_block, website, 'configuring', 40)

        # Apply base configuration
        configure_website_defaults(website)

        # Start seeding
        website.start_seeding!
        report_progress(progress_block, website, 'seeding', 70)

        # Run seed pack
        run_seed_pack(website)

        # Mark ready
        website.mark_ready!
        report_progress(progress_block, website, 'ready', 95)

        # Auto-go-live (can be changed to require admin approval)
        website.go_live!
        report_progress(progress_block, website, 'live', 100)

        # Complete user onboarding
        owner = website.user_memberships.find_by(role: 'owner')&.user
        if owner
          owner.update!(onboarding_step: 4)
          # Use activate! which works from any pre-active state
          owner.activate! if owner.may_activate?
        end

        success_result(website: website)
      rescue StandardError => e
        Rails.logger.error("Provisioning failed for website #{website.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        website.fail_provisioning!(e.message) if website.may_fail_provisioning?
        @errors << "Provisioning failed: #{e.message}"
        failure_result
      end
    end

    # Retry a failed provisioning
    def retry_provisioning(website:)
      @errors = []

      unless website.failed?
        @errors << "Website is not in failed state"
        return failure_result
      end

      website.retry_provisioning!
      provision_website(website: website)
    end

    # Check subdomain availability
    def check_subdomain_availability(name)
      SubdomainGenerator.validate_custom_name(name)
    end

    # Get a random available subdomain suggestion
    def suggest_subdomain
      SubdomainGenerator.generate
    end

    private

    def seed_pack_for_site_type(site_type)
      case site_type
      when 'residential' then 'base'  # Will be 'residential' when pack exists
      when 'commercial' then 'base'   # Will be 'commercial' when pack exists
      when 'vacation_rental' then 'base'  # Will be 'vacation_rentals' when pack exists
      else 'base'
      end
    end

    def configure_website_defaults(website)
      # Set default theme based on site type
      theme_name = case website.site_type
                   when 'residential' then 'bristol'
                   when 'commercial' then 'bristol'
                   when 'vacation_rental' then 'bristol'
                   else 'bristol'
                   end

      website.update!(
        theme_name: theme_name,
        default_client_locale: 'en',
        supported_locales: ['en']
      )
    end

    def run_seed_pack(website)
      pack_name = website.seed_pack_name || 'base'

      # Set current website context for seeding
      Pwb::Current.website = website

      # Try to use SeedPack infrastructure
      begin
        if defined?(Pwb::SeedPack)
          seed_pack = Pwb::SeedPack.find(pack_name)
          seed_pack.apply!(website: website, options: { verbose: false })
          return
        end
      rescue Pwb::SeedPack::PackNotFoundError => e
        Rails.logger.info("Seed pack '#{pack_name}' not found: #{e.message}")
      rescue StandardError => e
        Rails.logger.warn("SeedPack failed for '#{pack_name}': #{e.message}, falling back to basic seeder")
      end

      # Fallback to basic seeder
      Rails.logger.info("Using basic seeder for website #{website.id}")
      Pwb::Seeder.new.seed_for_website(website)
    end

    def report_progress(progress_block, website, state, percentage)
      return unless progress_block
      progress_block.call({ state: state, percentage: percentage, message: website.provisioning_status_message })
    end

    def find_reserved_subdomain(email)
      Subdomain.reserved.find_by(reserved_by_email: email.downcase.strip)
    end

    def success_result(data = {})
      { success: true, errors: [] }.merge(data)
    end

    def failure_result
      { success: false, errors: @errors }
    end
  end
end
