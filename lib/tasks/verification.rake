# frozen_string_literal: true

namespace :verification do
  desc "List all websites pending email verification with their verification links"
  task pending: :environment do
    puts "\n=== Websites Pending Email Verification ===\n\n"

    pending_verification = Pwb::Website.where(provisioning_state: 'locked_pending_email_verification')
    pending_registration = Pwb::Website.where(provisioning_state: 'locked_pending_registration')

    if pending_verification.empty? && pending_registration.empty?
      puts "No websites pending verification or registration.\n\n"
      exit
    end

    base_domain = ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
    verification_base_url = ENV.fetch('VERIFICATION_BASE_URL', "https://#{base_domain}")

    if pending_verification.any?
      puts "--- Awaiting Email Verification (#{pending_verification.count}) ---\n\n"

      pending_verification.find_each do |website|
        VerificationHelper.print_website_info(website, base_domain, verification_base_url, :email_verification)
      end
    end

    if pending_registration.any?
      puts "\n--- Email Verified, Awaiting Registration (#{pending_registration.count}) ---\n\n"

      pending_registration.find_each do |website|
        VerificationHelper.print_website_info(website, base_domain, verification_base_url, :registration)
      end
    end

    puts "\n=== Summary ===\n"
    puts "Pending email verification: #{pending_verification.count}"
    puts "Pending registration: #{pending_registration.count}"
    puts ""
  end

  desc "Resend verification email for a specific website (by subdomain or ID)"
  task :resend, [:identifier] => :environment do |_t, args|
    identifier = args[:identifier]

    if identifier.blank?
      puts "Usage: rake verification:resend[subdomain_or_id]"
      exit 1
    end

    website = Pwb::Website.find_by(id: identifier) || Pwb::Website.find_by(subdomain: identifier)

    if website.nil?
      puts "Website not found: #{identifier}"
      exit 1
    end

    unless website.locked_pending_email_verification?
      puts "Website '#{website.subdomain}' is not pending email verification."
      puts "Current state: #{website.provisioning_state}"
      exit 1
    end

    website.regenerate_email_verification_token!
    Pwb::EmailVerificationMailer.verification_email(website).deliver_now

    puts "Verification email resent to: #{website.owner_email}"
    puts "New token expires at: #{website.email_verification_token_expires_at}"
  end

  desc "Show verification details for a specific website"
  task :show, [:identifier] => :environment do |_t, args|
    identifier = args[:identifier]

    if identifier.blank?
      puts "Usage: rake verification:show[subdomain_or_id]"
      exit 1
    end

    website = Pwb::Website.find_by(id: identifier) || Pwb::Website.find_by(subdomain: identifier)

    if website.nil?
      puts "Website not found: #{identifier}"
      exit 1
    end

    base_domain = ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
    verification_base_url = ENV.fetch('VERIFICATION_BASE_URL', "https://#{base_domain}")

    puts "\n=== Website Details ===\n\n"
    VerificationHelper.print_website_info(website, base_domain, verification_base_url, :full)
  end

end

# Helper module for verification rake tasks
module VerificationHelper
  def self.print_website_info(website, base_domain, verification_base_url, mode)
    site_url = "https://#{website.subdomain}.#{base_domain}"
    # Use the subdomain URL for verification link so it routes correctly
    verification_url = "#{site_url}/api/signup/verify_email?token=#{website.email_verification_token}"
    signup_url = "#{site_url}/pwb_sign_up?token=#{website.email_verification_token}"

    expired = website.email_verification_token_expires_at && website.email_verification_token_expires_at < Time.current

    puts "Website ID:    #{website.id}"
    puts "Subdomain:     #{website.subdomain}"
    puts "Owner Email:   #{website.owner_email || '(not set)'}"
    puts "State:         #{website.provisioning_state}"
    puts "Token:         #{website.email_verification_token || '(not set)'}"
    puts "Expires:       #{website.email_verification_token_expires_at || '(not set)'}#{expired ? ' [EXPIRED]' : ''}"

    case mode
    when :email_verification
      puts "Verify Link:   #{verification_url}" if website.email_verification_token
    when :registration
      puts "Signup Link:   #{signup_url}" if website.email_verification_token
    when :full
      puts "Site URL:      #{site_url}"
      puts "Verify Link:   #{verification_url}" if website.email_verification_token
      puts "Signup Link:   #{signup_url}" if website.email_verification_token
      puts "Email Verified: #{website.email_verified_at || 'No'}"
      puts "Created:       #{website.created_at}"
    end

    puts "-" * 60
    puts ""
  end
end
