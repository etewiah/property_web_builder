module Pwb
  # Generates Heroku-style subdomain names (adjective-noun-number)
  # Example: sunny-meadow-42, crystal-peak-17, golden-river-89
  class SubdomainGenerator
    ADJECTIVES = %w[
      amber ancient autumn azure bright calm clear coral cosmic crimson
      crystal dapper dawn dusk ember fading fallen fierce fiery gentle
      gilded golden graceful hidden icy jade keen lively lunar midnight
      misty noble ocean pearl polished pristine proud quiet radiant rapid
      royal rustic sacred serene shadow shining silent silver smooth snowy
      solar starry steady still stormy summer sunny swift twilight violet
      wandering warm wild winter wispy wooden young zesty
    ].freeze

    NOUNS = %w[
      bay beach bluff brook canyon cave cliff cloud coast cove creek
      delta dune field forest garden glade glen grove harbor haven hill
      hollow horizon inlet island lagoon lake landing meadow mesa mist
      moon mountain oasis ocean orchard passage path peak pine plains
      pond prairie rain reef ridge river rock sand shadow shore sky
      slope spring star stone storm stream summit sun sunset surf tide
      trail tree valley view village vista water wave willow wind wood
    ].freeze

    class << self
      # Generate a single unique subdomain name
      def generate
        loop do
          name = build_name
          return name unless Subdomain.exists?(name: name) || Website.exists?(subdomain: name)
        end
      end

      # Generate multiple unique subdomain names
      def generate_batch(count)
        names = []
        while names.length < count
          name = build_name
          next if Subdomain.exists?(name: name) || Website.exists?(subdomain: name)
          next if names.include?(name)
          names << name
        end
        names
      end

      # Populate the subdomain pool with pre-generated names
      def populate_pool(count: 1000, batch_size: 100)
        total_created = 0

        (count / batch_size).times do
          names = generate_batch(batch_size)
          subdomains = names.map { |name| { name: name, aasm_state: 'available', created_at: Time.current, updated_at: Time.current } }
          Subdomain.insert_all(subdomains)
          total_created += subdomains.length

          Rails.logger.info "SubdomainGenerator: Created #{total_created} subdomains..."
        end

        # Handle remainder
        remainder = count % batch_size
        if remainder > 0
          names = generate_batch(remainder)
          subdomains = names.map { |name| { name: name, aasm_state: 'available', created_at: Time.current, updated_at: Time.current } }
          Subdomain.insert_all(subdomains)
          total_created += subdomains.length
        end

        Rails.logger.info "SubdomainGenerator: Finished creating #{total_created} subdomains"
        total_created
      end

      # Ensure pool has minimum available subdomains
      def ensure_pool_minimum(minimum: 100)
        available_count = Subdomain.available.count
        if available_count < minimum
          needed = minimum - available_count
          populate_pool(count: needed)
          Rails.logger.info "SubdomainGenerator: Pool replenished with #{needed} subdomains"
        end
      end

      # Check if a custom subdomain is valid and available
      # Pass reserved_by_email to allow using a subdomain reserved by that email
      def validate_custom_name(name, reserved_by_email: nil)
        errors = []
        normalized = name.to_s.downcase.strip

        # Format validation
        unless normalized.match?(/\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/)
          errors << "can only contain lowercase letters, numbers, and hyphens (no leading/trailing hyphens)"
        end

        # Length validation
        if normalized.length < 3
          errors << "must be at least 3 characters"
        elsif normalized.length > 40
          errors << "must be 40 characters or fewer"
        end

        # Reserved name check
        if Website::RESERVED_SUBDOMAINS.include?(normalized)
          errors << "is reserved and cannot be used"
        end

        # Availability check
        if errors.empty?
          if Website.exists?(subdomain: normalized)
            errors << "is already taken"
          else
            pool_subdomain = Subdomain.find_by(name: normalized)
            if pool_subdomain
              case pool_subdomain.aasm_state
              when 'allocated'
                errors << "is already taken"
              when 'reserved'
                # Allow if reserved by the same email
                unless reserved_by_email && pool_subdomain.reserved_by_email == reserved_by_email.downcase
                  errors << "is not available"
                end
              end
            end
          end
        end

        { valid: errors.empty?, errors: errors, normalized: normalized }
      end

      private

      def build_name
        adjective = ADJECTIVES.sample
        noun = NOUNS.sample
        number = rand(10..99)
        "#{adjective}-#{noun}-#{number}"
      end
    end
  end
end
