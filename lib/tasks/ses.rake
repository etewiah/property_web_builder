# frozen_string_literal: true

namespace :ses do
  desc "Check Amazon SES configuration and status"
  task check: :environment do
    puts "\n=== Amazon SES Configuration Check ==="
    puts ""

    # Show configuration summary
    config = Pwb::SES.configuration_summary

    puts "SMTP Configuration:"
    puts "  Configured:  #{config[:smtp][:configured] ? 'Yes' : 'No'}"
    if config[:smtp][:configured]
      puts "  Address:     #{config[:smtp][:address]}"
      puts "  Port:        #{config[:smtp][:port]}"
      puts "  Username:    #{config[:smtp][:username]}"
      puts "  Auth:        #{config[:smtp][:auth]}"
    else
      puts "  (Set SMTP_ADDRESS, SMTP_USERNAME, SMTP_PASSWORD to enable)"
    end
    puts ""

    puts "SES API Configuration:"
    puts "  Configured:  #{config[:api][:configured] ? 'Yes' : 'No'}"
    if config[:api][:configured]
      puts "  Region:      #{config[:api][:region]}"
      puts "  Access Key:  #{config[:api][:access_key]}"
    else
      puts "  (Set AWS_SES_ACCESS_KEY_ID, AWS_SES_SECRET_ACCESS_KEY, AWS_SES_REGION to enable)"
    end
    puts ""

    puts "Mailer Settings:"
    puts "  Host:        #{config[:mailer][:host] || '(not set)'}"
    puts "  From:        #{config[:mailer][:from] || '(not set)'}"
    puts ""

    # If API is configured, get account info
    if Pwb::SES.api_configured?
      puts "=== SES Account Status ==="
      account = Pwb::SES.account_info

      if account[:error]
        puts "  ERROR: #{account[:error]}"
      else
        puts "  Production Access:    #{account[:production_access] ? 'Yes' : 'No (Sandbox mode)'}"
        puts "  Sending Enabled:      #{account[:sending_enabled] ? 'Yes' : 'No'}"
        puts "  Enforcement Status:   #{account[:enforcement_status]}"
        if account[:send_quota]
          puts ""
          puts "  Send Quota (24h):"
          puts "    Max sends:          #{account[:send_quota][:max_24_hour_send]}"
          puts "    Max send rate:      #{account[:send_quota][:max_send_rate]}/sec"
          puts "    Sent last 24h:      #{account[:send_quota][:sent_last_24_hours]}"
        end
      end
      puts ""

      puts "=== Verified Identities ==="
      identities = Pwb::SES.verified_identities

      if identities.empty?
        puts "  No verified identities found."
        puts "  Add verified domains/emails in AWS SES console."
      elsif identities.first[:error]
        puts "  ERROR: #{identities.first[:error]}"
      else
        identities.each do |identity|
          status = identity[:sending_enabled] ? "OK" : "DISABLED"
          puts "  [#{status}] #{identity[:name]} (#{identity[:type]})"
        end
      end
      puts ""
    end

    # Test SMTP connection if configured
    if Pwb::SES.smtp_configured?
      puts "=== SMTP Connection Test ==="
      begin
        require 'net/smtp'

        address = ENV["SMTP_ADDRESS"]
        port = ENV.fetch("SMTP_PORT", 587).to_i

        puts "  Connecting to #{address}:#{port}..."

        Net::SMTP.start(
          address,
          port,
          ENV.fetch("SMTP_DOMAIN", "localhost"),
          ENV["SMTP_USERNAME"],
          ENV["SMTP_PASSWORD"],
          ENV.fetch("SMTP_AUTH", "login").to_sym
        ) do |smtp|
          puts "  Connection successful!"
          puts "  Server: #{smtp.instance_variable_get(:@smtp)&.server_info rescue 'N/A'}"
        end
      rescue StandardError => e
        puts "  Connection FAILED: #{e.message}"
        puts ""
        puts "  Common issues:"
        puts "    - Invalid credentials"
        puts "    - Wrong region endpoint"
        puts "    - Firewall blocking port #{port}"
        puts "    - Account in sandbox (can only send to verified emails)"
      end
      puts ""
    end

    puts "=== Required Environment Variables ==="
    puts ""
    puts "For SMTP delivery:"
    puts "  SMTP_ADDRESS=email-smtp.<region>.amazonaws.com"
    puts "  SMTP_PORT=587"
    puts "  SMTP_USERNAME=<your-ses-smtp-username>"
    puts "  SMTP_PASSWORD=<your-ses-smtp-password>"
    puts "  SMTP_AUTH=login"
    puts ""
    puts "For SES API features:"
    puts "  AWS_SES_ACCESS_KEY_ID=<your-access-key>"
    puts "  AWS_SES_SECRET_ACCESS_KEY=<your-secret-key>"
    puts "  AWS_SES_REGION=us-east-1"
    puts ""
    puts "Optional:"
    puts "  MAILER_HOST=yourdomain.com"
    puts "  DEFAULT_FROM_EMAIL=noreply@yourdomain.com"
    puts ""
  end

  desc "List verified identities in SES"
  task identities: :environment do
    unless Pwb::SES.api_configured?
      puts "ERROR: SES API not configured"
      puts "Set AWS_SES_ACCESS_KEY_ID and AWS_SES_SECRET_ACCESS_KEY"
      exit 1
    end

    puts "\n=== SES Verified Identities ==="
    puts ""

    identities = Pwb::SES.verified_identities

    if identities.empty?
      puts "No verified identities found."
    elsif identities.first[:error]
      puts "ERROR: #{identities.first[:error]}"
      exit 1
    else
      identities.each do |identity|
        status = identity[:sending_enabled] ? "ENABLED" : "DISABLED"
        puts "  #{identity[:name].ljust(40)} #{identity[:type].ljust(10)} #{status}"
      end
    end
    puts ""
  end

  desc "Check if a specific identity (email/domain) is verified"
  task :verify_identity, [:identity] => :environment do |_, args|
    identity = args[:identity]

    if identity.blank?
      puts "Usage: rails ses:verify_identity[email@example.com]"
      puts "       rails ses:verify_identity[example.com]"
      exit 1
    end

    unless Pwb::SES.api_configured?
      puts "ERROR: SES API not configured"
      exit 1
    end

    puts "\nChecking identity: #{identity}"

    if Pwb::SES.identity_verified?(identity)
      puts "  Status: VERIFIED (can send emails)"
    else
      puts "  Status: NOT VERIFIED"
      puts ""
      puts "  To verify this identity:"
      puts "    1. Go to AWS SES Console"
      puts "    2. Navigate to Verified identities"
      puts "    3. Click 'Create identity'"
      puts "    4. Follow the verification steps"
    end
    puts ""
  end

  desc "Send a test email via SES API"
  task :test_email, [:to] => :environment do |_, args|
    to = args[:to]

    if to.blank?
      puts "Usage: rails ses:test_email[recipient@example.com]"
      exit 1
    end

    unless Pwb::SES.api_configured?
      puts "ERROR: SES API not configured"
      puts "Set AWS_SES_ACCESS_KEY_ID and AWS_SES_SECRET_ACCESS_KEY"
      exit 1
    end

    from = ENV.fetch("DEFAULT_FROM_EMAIL") { "noreply@example.com" }

    puts "\n=== Sending Test Email via SES API ==="
    puts "  From: #{from}"
    puts "  To:   #{to}"
    puts ""

    result = Pwb::SES.send_test_email(to: to, from: from)

    if result[:success]
      puts "  SUCCESS!"
      puts "  Message ID: #{result[:message_id]}"
    else
      puts "  FAILED: #{result[:error]}"
      puts ""
      puts "  Common issues:"
      puts "    - Sender email/domain not verified"
      puts "    - In sandbox mode: recipient must be verified too"
      puts "    - Invalid credentials"
    end
    puts ""
  end

  desc "Send a test email via SMTP (ActionMailer)"
  task :test_smtp, [:to] => :environment do |_, args|
    to = args[:to]

    if to.blank?
      puts "Usage: rails ses:test_smtp[recipient@example.com]"
      exit 1
    end

    unless Pwb::SES.smtp_configured?
      puts "ERROR: SMTP not configured"
      puts "Set SMTP_ADDRESS, SMTP_USERNAME, SMTP_PASSWORD"
      exit 1
    end

    from = ENV.fetch("DEFAULT_FROM_EMAIL") { "noreply@example.com" }

    puts "\n=== Sending Test Email via SMTP ==="
    puts "  From:   #{from}"
    puts "  To:     #{to}"
    puts "  Server: #{ENV['SMTP_ADDRESS']}:#{ENV.fetch('SMTP_PORT', 587)}"
    puts ""

    begin
      mail = ActionMailer::Base.mail(
        from: from,
        to: to,
        subject: "SES SMTP Test Email from PropertyWebBuilder",
        body: "This is a test email sent via Amazon SES SMTP.\n\nTimestamp: #{Time.current}"
      )

      mail.deliver_now

      puts "  SUCCESS! Email sent."
    rescue StandardError => e
      puts "  FAILED: #{e.message}"
      puts ""
      puts "  Common issues:"
      puts "    - Invalid SMTP credentials"
      puts "    - Sender not verified in SES"
      puts "    - In sandbox: recipient must be verified"
    end
    puts ""
  end

  desc "Show SES account quota and statistics"
  task quota: :environment do
    unless Pwb::SES.api_configured?
      puts "ERROR: SES API not configured"
      exit 1
    end

    puts "\n=== SES Account Quota ==="
    account = Pwb::SES.account_info

    if account[:error]
      puts "ERROR: #{account[:error]}"
      exit 1
    end

    puts ""
    puts "  Production Access:  #{account[:production_access] ? 'Yes' : 'No (Sandbox)'}"
    puts "  Sending Enabled:    #{account[:sending_enabled] ? 'Yes' : 'No'}"
    puts "  Enforcement:        #{account[:enforcement_status]}"

    if account[:send_quota]
      quota = account[:send_quota]
      puts ""
      puts "  24-Hour Send Limit: #{quota[:max_24_hour_send]}"
      puts "  Max Send Rate:      #{quota[:max_send_rate]} emails/second"
      puts "  Sent (last 24h):    #{quota[:sent_last_24_hours]}"

      if quota[:max_24_hour_send] && quota[:sent_last_24_hours]
        remaining = quota[:max_24_hour_send] - quota[:sent_last_24_hours]
        percentage = (quota[:sent_last_24_hours].to_f / quota[:max_24_hour_send] * 100).round(1)
        puts "  Remaining:          #{remaining} (#{percentage}% used)"
      end
    end
    puts ""
  end
end
