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

      result = ActiveRecord::Base.transaction do
        # Check if user already exists
        existing_user = User.find_by(email: email.downcase.strip)
        if existing_user
          if existing_user.active?
            @errors << "An account with this email already exists"
            raise ActiveRecord::Rollback
          else
            # Reactivate churned user
            existing_user.reactivate! if existing_user.churned?
            next success_result(user: existing_user, subdomain: find_reserved_subdomain(email))
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
        begin
          subdomain = Subdomain.reserve_for_email(email, duration: 10.minutes)
          unless subdomain
            @errors << "Unable to reserve a subdomain. Please try again later."
            raise ActiveRecord::Rollback
          end
        rescue Subdomain::SubdomainPoolEmptyError => e
          Rails.logger.error("[Provisioning] Subdomain pool empty during signup: #{e.message}")
          @errors << "We're setting up new subdomains. Please try again in a few minutes, or contact support."
          raise ActiveRecord::Rollback
        rescue Subdomain::SubdomainPoolExhaustedError => e
          Rails.logger.error("[Provisioning] Subdomain pool exhausted during signup: #{e.message}")
          @errors << "We're experiencing high demand. Please try again later, or contact support for assistance."
          raise ActiveRecord::Rollback
        end

        success_result(user: user, subdomain: subdomain)
      end

      # If transaction rolled back, result will be nil
      result || failure_result
    rescue Subdomain::SubdomainPoolEmptyError, Subdomain::SubdomainPoolExhaustedError => e
      # These are already handled above, but catch any that escape the transaction
      Rails.logger.error("[Provisioning] Subdomain pool error escaped transaction: #{e.message}")
      @errors << "Unable to complete signup. Please contact support." unless @errors.any?
      failure_result
    rescue StandardError => e
      Rails.logger.error("[Provisioning] Unexpected error in start_signup: #{e.class.name}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
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

    # Step 3: Configure site - set subdomain and site type, create owner
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

        # Create the website in pending state
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

        # Allocate subdomain to website in the pool
        pool_subdomain = Subdomain.find_by(name: validation[:normalized])
        if pool_subdomain
          pool_subdomain.allocate!(website) if pool_subdomain.may_allocate?
        end

        # Create owner membership - this is required for provisioning to proceed
        membership = UserMembership.create!(
          user: user,
          website: website,
          role: 'owner',
          active: true
        )

        # Update user's primary website
        user.update!(website: website)
        user.update!(onboarding_step: 3)

        # Transition to owner_assigned state (guard verifies owner exists)
        unless website.may_assign_owner?
          @errors << "Failed to verify owner assignment"
          raise ActiveRecord::Rollback
        end
        website.assign_owner!

        result = success_result(user: user, website: website, membership: membership)
      end

      result || failure_result
    rescue StandardError => e
      @errors << e.message
      failure_result
    end

    # Step 4: Provision website - run seeding and configuration
    # Uses granular state transitions with guards to ensure each step completes
    # Optionally pass a block to receive progress updates
    def provision_website(website:, skip_properties: false, &progress_block)
      @errors = []

      begin
        Rails.logger.info("[Provisioning] Starting provisioning for website #{website.id} (#{website.subdomain})")

        # Verify we're in a valid starting state
        unless website.owner_assigned? || website.pending?
          @errors << "Website must be in 'pending' or 'owner_assigned' state to provision (current: #{website.provisioning_state})"
          return failure_result
        end

        # If pending, we need an owner first
        if website.pending?
          unless website.has_owner?
            @errors << "Website must have an owner before provisioning"
            return failure_result
          end
          website.assign_owner!
        end

        report_progress(progress_block, website, 'owner_assigned', 15)

        # Step 1: Create agency
        Rails.logger.info("[Provisioning] Creating agency for website #{website.id}")
        create_agency_for_website(website)

        unless website.has_agency?
          fail_with_details(website, "Agency creation failed - no agency record found")
          return failure_result
        end
        website.complete_agency!
        report_progress(progress_block, website, 'agency_created', 30)

        # Step 2: Create navigation links
        Rails.logger.info("[Provisioning] Creating links for website #{website.id}")
        create_links_for_website(website)

        unless website.has_links?
          fail_with_details(website, "Links creation failed - need at least 3 links, have #{website.links.count}")
          return failure_result
        end
        website.complete_links!
        report_progress(progress_block, website, 'links_created', 45)

        # Step 3: Create field keys
        Rails.logger.info("[Provisioning] Creating field keys for website #{website.id}")
        create_field_keys_for_website(website)

        unless website.has_field_keys?
          fail_with_details(website, "Field keys creation failed - need at least 5, have #{website.field_keys.count}")
          return failure_result
        end
        website.complete_field_keys!
        report_progress(progress_block, website, 'field_keys_created', 60)

        # Step 4: Seed properties (optional)
        Rails.logger.info("[Provisioning] Seeding properties for website #{website.id} (skip=#{skip_properties})")
        if skip_properties
          website.skip_properties!
        else
          seed_properties_for_website(website)
          website.seed_properties!
        end
        report_progress(progress_block, website, 'properties_seeded', 80)

        # Step 5: Final verification and mark ready
        Rails.logger.info("[Provisioning] Final verification for website #{website.id}")
        unless website.provisioning_complete?
          missing = website.provisioning_missing_items
          fail_with_details(website, "Provisioning incomplete - missing: #{missing.join(', ')}")
          return failure_result
        end
        website.mark_ready!
        report_progress(progress_block, website, 'ready', 95)

        # Step 6: Enter locked state (awaiting email verification)
        Rails.logger.info("[Provisioning] Entering locked state for website #{website.id}")
        unless website.can_go_live?
          fail_with_details(website, "Cannot enter locked state - provisioning_complete=#{website.provisioning_complete?}, subdomain=#{website.subdomain.present?}")
          return failure_result
        end
        website.enter_locked_state!
        report_progress(progress_block, website, 'locked_pending_email_verification', 95)

        # Send verification email to owner
        send_verification_email(website)

        Rails.logger.info("[Provisioning] Successfully provisioned website #{website.id} (#{website.subdomain}) - awaiting email verification")
        success_result(website: website)

      rescue AASM::InvalidTransition => e
        error_msg = "State transition failed: #{e.message}. Current state: #{website.provisioning_state}, Checklist: #{website.provisioning_checklist.to_json}"
        Rails.logger.error("[Provisioning] #{error_msg}")
        fail_with_details(website, error_msg)
        failure_result

      rescue StandardError => e
        Rails.logger.error("[Provisioning] Failed for website #{website.id}: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        fail_with_details(website, e.message)
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

    # ===================
    # Provisioning Steps
    # ===================

    # Create agency record for the website
    def create_agency_for_website(website)
      return if website.agency.present?

      Pwb::Current.website = website

      # Try seed pack first
      if try_seed_pack_step(website, :agency)
        return
      end

      # Fallback: create minimal agency
      website.create_agency!(
        display_name: website.subdomain.titleize,
        email_primary: "info@#{website.subdomain}.example.com"
      )
    end

    # Create navigation links for the website
    def create_links_for_website(website)
      return if website.links.count >= 3

      Pwb::Current.website = website

      # Try seed pack first
      if try_seed_pack_step(website, :links)
        return
      end

      # Fallback: create minimal links
      default_links = [
        { slug: 'home', link_url: '/', visible: true },
        { slug: 'properties', link_url: '/search', visible: true },
        { slug: 'about', link_url: '/about', visible: true },
        { slug: 'contact', link_url: '/contact', visible: true }
      ]

      default_links.each_with_index do |link_attrs, index|
        website.links.find_or_create_by!(slug: link_attrs[:slug]) do |link|
          link.assign_attributes(link_attrs.merge(sort_order: index + 1))
        end
      end
    end

    # Create field keys for the website
    def create_field_keys_for_website(website)
      return if website.field_keys.count >= 5

      Pwb::Current.website = website

      # Try seed pack first
      if try_seed_pack_step(website, :field_keys)
        return
      end

      # Fallback: create minimal field keys
      default_field_keys = [
        { global_key: 'types.house', tag: 'property-types', visible: true },
        { global_key: 'types.apartment', tag: 'property-types', visible: true },
        { global_key: 'types.villa', tag: 'property-types', visible: true },
        { global_key: 'states.good', tag: 'property-states', visible: true },
        { global_key: 'states.new', tag: 'property-states', visible: true },
        { global_key: 'features.pool', tag: 'property-features', visible: true },
        { global_key: 'features.garage', tag: 'property-features', visible: true }
      ]

      default_field_keys.each do |fk_attrs|
        website.field_keys.find_or_create_by!(global_key: fk_attrs[:global_key]) do |fk|
          fk.assign_attributes(fk_attrs)
        end
      end
    end

    # Seed sample properties for the website
    def seed_properties_for_website(website)
      Pwb::Current.website = website

      # Try seed pack first
      if try_seed_pack_step(website, :properties)
        return
      end

      # Fallback: use basic seeder for properties only
      begin
        seeder = Pwb::Seeder.new
        seeder.seed_properties_for_website(website) if seeder.respond_to?(:seed_properties_for_website)
      rescue StandardError => e
        Rails.logger.warn("[Provisioning] Property seeding failed (non-fatal): #{e.message}")
        # Properties are optional, don't fail provisioning
      end
    end

    # Try to run a specific step from the seed pack
    # Returns true if seed pack handled the step AND the data exists, false otherwise
    def try_seed_pack_step(website, step)
      pack_name = website.seed_pack_name || 'base'

      begin
        if defined?(Pwb::SeedPack)
          seed_pack = Pwb::SeedPack.find(pack_name)

          case step
          when :agency
            seed_pack.seed_agency!(website: website) if seed_pack.respond_to?(:seed_agency!)
            return website.agency.present?  # Verify it worked
          when :links
            seed_pack.seed_links!(website: website) if seed_pack.respond_to?(:seed_links!)
            return website.links.count >= 3  # Verify minimum links exist
          when :field_keys
            seed_pack.seed_field_keys!(website: website) if seed_pack.respond_to?(:seed_field_keys!)
            return website.field_keys.count >= 5  # Verify minimum field keys exist
          when :properties
            seed_pack.seed_properties!(website: website) if seed_pack.respond_to?(:seed_properties!)
            return true  # Properties are optional, just return true
          end
        end
      rescue Pwb::SeedPack::PackNotFoundError
        # Pack doesn't exist, use fallback
      rescue NoMethodError
        # Method doesn't exist on pack, use fallback
      rescue StandardError => e
        Rails.logger.warn("[Provisioning] SeedPack step '#{step}' failed: #{e.message}")
      end

      false
    end

    # Complete owner's onboarding after successful provisioning
    def complete_owner_onboarding(website)
      owner = website.user_memberships.find_by(role: 'owner')&.user
      return unless owner

      owner.update!(onboarding_step: 4)
      owner.activate! if owner.respond_to?(:may_activate?) && owner.may_activate?
    rescue StandardError => e
      # Don't fail provisioning if user update fails
      Rails.logger.warn("[Provisioning] Owner onboarding update failed (non-fatal): #{e.message}")
    end

    # Send email verification to the website owner
    def send_verification_email(website)
      return unless website.owner_email.present?

      EmailVerificationMailer.verification_email(website).deliver_later
      Rails.logger.info("[Provisioning] Sent verification email to #{website.owner_email} for website #{website.id}")
    rescue StandardError => e
      # Don't fail provisioning if email fails - they can request resend
      Rails.logger.warn("[Provisioning] Failed to send verification email (non-fatal): #{e.message}")
    end

    # ===================
    # Failure Handling
    # ===================

    def fail_with_details(website, error_message)
      @errors << "Provisioning failed: #{error_message}"
      website.fail_provisioning!(error_message) if website.may_fail_provisioning?
    end

    # ===================
    # Utilities
    # ===================

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
