# frozen_string_literal: true

namespace :zoho do
  desc "Check Zoho CRM configuration status"
  task status: :environment do
    client = Pwb::Zoho::Client.instance

    puts "\n=== Zoho CRM Integration Status ==="

    if client.configured?
      puts "Status: CONFIGURED"
      puts ""

      # Test the connection
      print "Testing API connection... "
      begin
        # Try to get organization info as a simple API test
        response = client.get('/org')
        if response['org']
          puts "SUCCESS"
          org = response['org'].first
          puts "  Organization: #{org['company_name']}" if org
        else
          puts "Connected (no org data returned)"
        end
      rescue Pwb::Zoho::AuthenticationError => e
        puts "FAILED"
        puts "  Error: Authentication failed - #{e.message}"
        puts "  Action: Regenerate your refresh token"
      rescue Pwb::Zoho::Error => e
        puts "FAILED"
        puts "  Error: #{e.message}"
      end
    else
      puts "Status: NOT CONFIGURED"
      puts ""
      puts "Missing configuration. Set the following:"
      puts "  - ZOHO_CLIENT_ID"
      puts "  - ZOHO_CLIENT_SECRET"
      puts "  - ZOHO_REFRESH_TOKEN"
      puts ""
      puts "Or in Rails credentials:"
      puts "  zoho:"
      puts "    client_id: \"...\""
      puts "    client_secret: \"...\""
      puts "    refresh_token: \"...\""
    end

    puts ""
  end

  desc "Generate OAuth tokens for Zoho CRM (interactive)"
  task generate_tokens: :environment do
    puts "\n=== Zoho CRM OAuth Token Generator ===\n"

    # Check for client credentials
    client_id = ENV['ZOHO_CLIENT_ID'] || Rails.application.credentials.dig(:zoho, :client_id)
    client_secret = ENV['ZOHO_CLIENT_SECRET'] || Rails.application.credentials.dig(:zoho, :client_secret)

    unless client_id && client_secret
      puts "ERROR: Client ID and Secret are required."
      puts ""
      puts "Set these environment variables first:"
      puts "  export ZOHO_CLIENT_ID='your_client_id'"
      puts "  export ZOHO_CLIENT_SECRET='your_client_secret'"
      puts ""
      puts "Get these from https://api-console.zoho.com/"
      exit 1
    end

    # Build authorization URL
    redirect_uri = ENV.fetch('ZOHO_REDIRECT_URI', 'http://localhost:3000/zoho/callback')
    scopes = [
      'ZohoCRM.modules.leads.ALL',
      'ZohoCRM.modules.deals.ALL',
      'ZohoCRM.modules.contacts.ALL',
      'ZohoCRM.modules.accounts.ALL',
      'ZohoCRM.modules.notes.ALL',
      'ZohoCRM.settings.ALL',
      'ZohoCRM.users.READ',
      'ZohoCRM.org.READ'
    ].join(',')

    accounts_url = ENV.fetch('ZOHO_ACCOUNTS_URL', 'https://accounts.zoho.com')

    auth_url = "#{accounts_url}/oauth/v2/auth?" + {
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scopes,
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent'
    }.to_query

    puts "Step 1: Open this URL in your browser to authorize:"
    puts ""
    puts auth_url
    puts ""
    puts "Step 2: After authorizing, you'll be redirected to #{redirect_uri}"
    puts "        (The page will show an error - that's expected)"
    puts ""
    puts "        Look at the URL in your browser's address bar. It will look like:"
    puts "        #{redirect_uri}?code=XXXX.YYYY.ZZZZ&..."
    puts ""
    puts "        Copy the 'code' parameter value (everything after 'code=' and before '&')"
    puts ""
    print "Step 3: Paste the authorization code here: "

    code = $stdin.gets.chomp

    if code.empty?
      puts "ERROR: No code provided."
      exit 1
    end

    # Exchange code for tokens
    puts ""
    puts "Exchanging code for tokens..."

    require 'faraday'

    response = Faraday.post("#{accounts_url}/oauth/v2/token") do |req|
      req.params = {
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      }
    end

    data = JSON.parse(response.body)

    if data['refresh_token']
      puts ""
      puts "SUCCESS! Here are your tokens:"
      puts ""
      puts "Access Token (expires in #{data['expires_in']}s):"
      puts data['access_token']
      puts ""
      puts "Refresh Token (save this - it's long-lived):"
      puts data['refresh_token']
      puts ""
      puts "API Domain:"
      puts data['api_domain']
      puts ""
      puts "Add to your Rails credentials (rails credentials:edit):"
      puts ""
      puts "zoho:"
      puts "  client_id: \"#{client_id}\""
      puts "  client_secret: \"#{client_secret}\""
      puts "  refresh_token: \"#{data['refresh_token']}\""
      puts "  api_domain: \"#{data['api_domain']}\""
      puts "  accounts_url: \"#{accounts_url}\""
    else
      puts ""
      puts "ERROR: Token exchange failed"
      puts "Response: #{data}"
    end

    puts ""
  end

  desc "Sync a specific user to Zoho CRM"
  task :sync_user, [:user_id] => :environment do |_t, args|
    user_id = args[:user_id]

    unless user_id
      puts "Usage: rake zoho:sync_user[USER_ID]"
      exit 1
    end

    user = Pwb::User.find(user_id)
    service = Pwb::Zoho::LeadSyncService.new

    if user.zoho_synced?
      puts "User #{user.id} already synced to Zoho (Lead ID: #{user.zoho_lead_id})"
      print "Update existing lead? (y/n): "
      exit 0 unless $stdin.gets.chomp.downcase == 'y'
    end

    puts "Syncing user #{user.id} (#{user.email}) to Zoho CRM..."

    result = service.create_lead_from_signup(user)

    if result
      puts "SUCCESS: Created lead #{result}"
    else
      puts "FAILED: Check logs for details"
    end
  end

  desc "Run trial reminder check (updates Zoho for trials ending soon)"
  task trial_reminders: :environment do
    puts "Running trial reminder check..."
    Pwb::Zoho::TrialReminderJob.perform_now
    puts "Done."
  end

  desc "Show Zoho sync statistics"
  task stats: :environment do
    puts "\n=== Zoho Sync Statistics ==="

    total_users = Pwb::User.count
    synced_users = Pwb::User.where("metadata->>'zoho_lead_id' IS NOT NULL").count
    converted_users = Pwb::User.where("metadata->>'zoho_contact_id' IS NOT NULL").count

    puts ""
    puts "Users:"
    puts "  Total:     #{total_users}"
    puts "  Synced:    #{synced_users} (#{(synced_users.to_f / total_users * 100).round(1)}%)"
    puts "  Converted: #{converted_users}"
    puts ""

    # Recent syncs
    recent_syncs = Pwb::User.where("metadata->>'zoho_synced_at' IS NOT NULL")
                           .order(Arel.sql("metadata->>'zoho_synced_at' DESC"))
                           .limit(5)

    if recent_syncs.any?
      puts "Recent Syncs:"
      recent_syncs.each do |user|
        synced_at = user.metadata['zoho_synced_at']
        puts "  #{user.email} - #{synced_at}"
      end
    end

    puts ""
  end
end
