module Pwb
  class Subdomain < ApplicationRecord
    include AASM

    belongs_to :website, optional: true

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validates :name,
              format: {
                with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/,
                message: "can only contain lowercase alphanumeric characters and hyphens"
              },
              length: { minimum: 5, maximum: 40 }

    # Reserved names that cannot be allocated
    RESERVED_NAMES = Website::RESERVED_SUBDOMAINS

    validate :name_not_reserved
    validate :name_not_profane

    scope :available, -> { where(aasm_state: 'available') }
    scope :reserved, -> { where(aasm_state: 'reserved') }
    scope :allocated, -> { where(aasm_state: 'allocated') }
    scope :expired_reservations, -> { reserved.where('reserved_until < ?', Time.current) }

    aasm column: :aasm_state do
      state :available, initial: true
      state :reserved
      state :allocated
      state :released

      event :reserve do
        transitions from: :available, to: :reserved, guard: :can_reserve?
        after do |email, duration = 5.minutes|
          update!(
            reserved_at: Time.current,
            reserved_until: Time.current + duration,
            reserved_by_email: email
          )
        end
      end

      event :allocate do
        transitions from: :reserved, to: :allocated
        transitions from: :available, to: :allocated  # Allow direct allocation
        after do |website|
          update!(
            website: website,
            reserved_at: nil,
            reserved_until: nil,
            reserved_by_email: nil
          )
        end
      end

      event :release do
        transitions from: [:reserved, :allocated], to: :released
        after do
          update!(
            website: nil,
            reserved_at: nil,
            reserved_until: nil,
            reserved_by_email: nil
          )
        end
      end

      event :make_available do
        transitions from: :released, to: :available
      end
    end

    # Reserve a subdomain for an email, with automatic expiry
    # Returns a hash with :subdomain or :error key
    def self.reserve_for_email(email, duration: 5.minutes)
      transaction do
        # First, release any expired reservations for this email
        expired_reservations.where(reserved_by_email: email).find_each(&:release!)

        # Try to find existing reservation for this email
        existing = reserved.find_by(reserved_by_email: email)
        return existing if existing && existing.reserved_until > Time.current

        # Find a random available subdomain
        subdomain = available.order('RANDOM()').lock.first

        unless subdomain
          available_count = available.count
          total_count = count

          error_details = {
            email: email,
            available_count: available_count,
            total_count: total_count,
            reserved_count: reserved.count,
            allocated_count: allocated.count
          }

          Rails.logger.error("[SubdomainPool] No available subdomains for reservation: #{error_details.to_json}")

          if total_count == 0
            raise SubdomainPoolEmptyError, "Subdomain pool is empty. Run: rails pwb:provisioning:populate_subdomains"
          elsif available_count == 0
            raise SubdomainPoolExhaustedError, "All #{total_count} subdomains are in use. Run: rails pwb:provisioning:populate_subdomains COUNT=100"
          end

          return nil
        end

        subdomain.reserve!(email, duration)
        subdomain
      end
    end

    # Custom errors for better debugging
    class SubdomainPoolEmptyError < StandardError; end
    class SubdomainPoolExhaustedError < StandardError; end

    # Find or reserve a specific subdomain by name
    def self.reserve_specific(name, email, duration: 5.minutes)
      transaction do
        subdomain = find_by(name: name.downcase)
        return nil unless subdomain&.may_reserve?

        subdomain.reserve!(email, duration)
        subdomain
      end
    end

    # Check if a specific name is available (either doesn't exist or is available state)
    def self.name_available?(name)
      subdomain = find_by(name: name.downcase)
      return true unless subdomain  # Not in pool, check Website model
      subdomain.available?
    end

    # Allocate a subdomain to a website
    def self.allocate_to_website(name_or_email:, website:)
      transaction do
        # First try to find by reserved email
        subdomain = reserved.find_by(reserved_by_email: name_or_email)

        # If not found by email, try by name
        subdomain ||= find_by(name: name_or_email.downcase)

        return false unless subdomain&.may_allocate?

        subdomain.allocate!(website)
        true
      end
    end

    # Release expired reservations (run via cron/scheduled job)
    def self.release_expired!
      expired_reservations.find_each do |subdomain|
        subdomain.release!
        subdomain.make_available!
      end
    end

    private

    def can_reserve?
      reserved_until.nil? || reserved_until < Time.current
    end

    def name_not_reserved
      return if name.blank?
      if RESERVED_NAMES.include?(name.downcase)
        errors.add(:name, "is reserved and cannot be used")
      end
    end

    def name_not_profane
      return if name.blank?
      if Obscenity.profane?(name.gsub('-', ' '))
        errors.add(:name, "contains inappropriate language")
      end
    end
  end
end
