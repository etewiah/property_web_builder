# frozen_string_literal: true

# Website::DomainConfigurable
#
# Manages custom domain configuration, verification, and platform domain handling.
# Provides methods for domain lookup, DNS verification, and URL generation.
#
module Website
  module DomainConfigurable
    extend ActiveSupport::Concern

    RESERVED_SUBDOMAINS = %w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test].freeze

    included do
      # Subdomain validations
      validates :subdomain,
                uniqueness: { case_sensitive: false, allow_blank: true },
                format: {
                  with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/i,
                  message: "can only contain alphanumeric characters and hyphens, and cannot start or end with a hyphen",
                  allow_blank: true
                },
                length: { minimum: 2, maximum: 63, allow_blank: true }

      # Custom domain validations
      validates :custom_domain,
                uniqueness: { case_sensitive: false, allow_blank: true },
                format: {
                  with: /\A([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)+[a-z]{2,}\z/i,
                  message: "must be a valid domain name (e.g., www.example.com or example.com)",
                  allow_blank: true
                },
                length: { maximum: 253, allow_blank: true }

      validate :subdomain_not_reserved
      validate :subdomain_not_profane
      validate :custom_domain_not_platform_domain
    end

    class_methods do
      # Find a website by subdomain (case-insensitive)
      def find_by_subdomain(subdomain)
        return nil if subdomain.blank?
        where("LOWER(subdomain) = ?", subdomain.downcase).first
      end

      # Find a website by custom domain (case-insensitive, handles www prefix)
      def find_by_custom_domain(domain)
        return nil if domain.blank?

        normalized = normalize_domain(domain)

        # Try exact match first
        website = where("LOWER(custom_domain) = ?", normalized.downcase).first
        return website if website

        # Try with www prefix if not present, or without if present
        if normalized.start_with?('www.')
          where("LOWER(custom_domain) = ?", normalized.sub(/\Awww\./, '').downcase).first
        else
          where("LOWER(custom_domain) = ?", "www.#{normalized}".downcase).first
        end
      end

      # Find a website by either subdomain or custom domain based on the host
      def find_by_host(host)
        return nil if host.blank?

        host = host.to_s.downcase.strip

        # First try custom domain lookup (for non-platform domains)
        unless platform_domain?(host)
          website = find_by_custom_domain(host)
          return website if website
        end

        # Fall back to subdomain lookup
        subdomain = extract_subdomain_from_host(host)
        find_by_subdomain(subdomain) if subdomain.present?
      end

      # Normalize a domain by removing protocol, path, and port
      def normalize_domain(domain)
        domain.to_s.downcase.strip
              .sub(%r{\Ahttps?://}, '')
              .sub(%r{/.*\z}, '')
              .sub(/:\d+\z/, '')
      end

      # Check if a host is a platform domain
      def platform_domain?(host)
        platform_domains.any? { |pd| host.end_with?(pd) }
      end

      # Extract subdomain from a platform domain host
      def extract_subdomain_from_host(host)
        platform_domains.each do |pd|
          if host.end_with?(pd)
            subdomain_part = host.sub(/\.?#{Regexp.escape(pd)}\z/, '')
            return subdomain_part.split('.').first if subdomain_part.present?
          end
        end
        nil
      end

      # Get list of platform domains from configuration
      def platform_domains
        ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost').split(',').map(&:strip)
      end

      # Find website by email verification token
      def find_by_verification_token(token)
        return nil if token.blank?
        find_by(email_verification_token: token)
      end
    end

    # Generate a unique token for DNS verification of custom domain
    def generate_domain_verification_token!
      update!(custom_domain_verification_token: SecureRandom.hex(16))
    end

    # Verify custom domain ownership via DNS TXT record
    def verify_custom_domain!
      return false if custom_domain.blank? || custom_domain_verification_token.blank?

      begin
        require 'resolv'
        resolver = Resolv::DNS.new

        verification_host = "_pwb-verification.#{custom_domain.sub(/\Awww\./, '')}"
        txt_records = resolver.getresources(verification_host, Resolv::DNS::Resource::IN::TXT)

        verified = txt_records.any? { |record| record.strings.join == custom_domain_verification_token }

        if verified
          update!(
            custom_domain_verified: true,
            custom_domain_verified_at: Time.current
          )
        end

        verified
      rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
        Rails.logger.warn("Domain verification failed for #{custom_domain}: #{e.message}")
        false
      end
    end

    # Check if custom domain is verified or allowed (dev mode)
    def custom_domain_active?
      return false if custom_domain.blank?
      custom_domain_verified? || Rails.env.development? || Rails.env.test?
    end

    # Get the primary URL for this website
    def primary_url
      if custom_domain.present? && custom_domain_active?
        "https://#{custom_domain}"
      elsif subdomain.present?
        platform_domain = self.class.platform_domains.first
        "https://#{subdomain}.#{platform_domain}"
      else
        nil
      end
    end

    private

    def subdomain_not_reserved
      return if subdomain.blank?
      if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
        errors.add(:subdomain, "is reserved and cannot be used")
      end
    end

    def subdomain_not_profane
      return if subdomain.blank?
      if Obscenity.profane?(subdomain.gsub('-', ' '))
        errors.add(:subdomain, "contains inappropriate language")
      end
    end

    def custom_domain_not_platform_domain
      return if custom_domain.blank?

      self.class.platform_domains.each do |pd|
        if custom_domain.downcase.end_with?(pd)
          errors.add(:custom_domain, "cannot be a platform domain (#{pd})")
          return
        end
      end
    end
  end
end
