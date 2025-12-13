# frozen_string_literal: true

namespace :tls do
  desc "Check if a domain is valid for TLS certificate issuance"
  task :check, [:domain] => :environment do |_t, args|
    domain = args[:domain]

    if domain.blank?
      puts "Usage: rake tls:check[domain.example.com]"
      exit 1
    end

    normalized_domain = domain.to_s.downcase.strip
    puts "Checking domain: #{normalized_domain}"
    puts "-" * 50

    result = verify_domain(normalized_domain)

    case result[:status]
    when :ok
      puts "Status: ✓ OK"
      puts "Reason: #{result[:reason]}"
      puts "Certificate issuance: ALLOWED"
    when :forbidden
      puts "Status: ✗ FORBIDDEN"
      puts "Reason: #{result[:reason]}"
      puts "Certificate issuance: DENIED"
    when :not_found
      puts "Status: ? NOT FOUND"
      puts "Reason: #{result[:reason]}"
      puts "Certificate issuance: DENIED"
    end
  end

  def verify_domain(domain)
    if platform_subdomain?(domain)
      verify_platform_subdomain(domain)
    else
      verify_custom_domain(domain)
    end
  end

  def platform_subdomain?(domain)
    Pwb::Website.platform_domains.any? { |pd| domain.end_with?(".#{pd}") || domain == pd }
  end

  def verify_platform_subdomain(domain)
    subdomain = Pwb::Website.extract_subdomain_from_host(domain)

    if subdomain.blank?
      return { status: :ok, reason: "Platform domain" }
    end

    if Pwb::Website::RESERVED_SUBDOMAINS.include?(subdomain.downcase)
      return { status: :ok, reason: "Reserved subdomain" }
    end

    website = Pwb::Website.find_by_subdomain(subdomain)

    if website.nil?
      return { status: :not_found, reason: "Subdomain not registered" }
    end

    puts "Website ID: #{website.id}"
    puts "Subdomain: #{website.subdomain}"
    puts "Provisioning state: #{website.provisioning_state}"

    validate_website_status(website)
  end

  def verify_custom_domain(domain)
    website = Pwb::Website.find_by_custom_domain(domain)

    if website.nil?
      return { status: :not_found, reason: "Custom domain not registered" }
    end

    puts "Website ID: #{website.id}"
    puts "Subdomain: #{website.subdomain}"
    puts "Custom domain: #{website.custom_domain}"
    puts "Provisioning state: #{website.provisioning_state}"

    unless website.custom_domain_active?
      return { status: :forbidden, reason: "Custom domain not verified" }
    end

    validate_website_status(website)
  end

  def validate_website_status(website)
    case website.provisioning_state
    when 'live', 'ready'
      { status: :ok, reason: "Website active" }
    when 'suspended'
      { status: :forbidden, reason: "Website suspended" }
    when 'terminated'
      { status: :forbidden, reason: "Website terminated" }
    when 'failed'
      { status: :forbidden, reason: "Website provisioning failed" }
    else
      { status: :ok, reason: "Website provisioning in progress" }
    end
  end
end
