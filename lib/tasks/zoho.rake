# frozen_string_literal: true

namespace :zoho do
  desc "Check Zoho CRM configuration status"
  task status: :environment do
    client = Pwb::Zoho::Client.instance

    puts "\n=== Zoho CRM Integration Status ==="

    if client.configured?
      puts "Status: CONFIGURED"
      
      # Show configuration (without revealing full tokens)
      creds = Rails.application.credentials.zoho || {}
      client_id = creds[:client_id] || ENV['ZOHO_CLIENT_ID']
      api_domain = creds[:api_domain] || ENV['ZOHO_API_DOMAIN'] || 'https://www.zohoapis.com'
      accounts_url = creds[:accounts_url] || ENV['ZOHO_ACCOUNTS_URL'] || 'https://accounts.zoho.com'
      
      puts ""
      puts "Configuration:"
      puts "  Client ID: #{client_id ? "#{client_id[0..10]}...#{client_id[-4..]}" : 'not set'}"
      puts "  API Domain: #{api_domain}"
      puts "  Accounts URL: #{accounts_url}"
      puts ""

      # Test the connection
      print "Testing API connection... "
      begin
        # Try to get users as a simple API test (most reliable endpoint)
        # Note: Zoho API is case-sensitive for parameter names
        response = client.get('/users', { 'type' => 'CurrentUser' })
        if response['users']
          puts "SUCCESS"
          user = response['users'].first
          puts "  Connected as: #{user['full_name']} (#{user['email']})" if user
        elsif response['code'] == 'SUCCESS' || response.key?('users')
          puts "SUCCESS (authenticated)"
        else
          puts "Connected (unexpected response format)"
          puts "  Response: #{response.inspect[0..100]}"
        end
      rescue Pwb::Zoho::AuthenticationError => e
        puts "FAILED"
        puts "  Error: Authentication failed - #{e.message}"
        puts "  Action: Your refresh token may have expired. Run: rake zoho:generate_tokens"
      rescue Pwb::Zoho::Error => e
        puts "FAILED"
        puts "  Error: #{e.message}"
        puts "  "
        puts "  Common causes:"
        puts "    - Refresh token expired (regenerate with: rake zoho:generate_tokens)"
        puts "    - Wrong API domain (check if you need .eu, .in, .com.au, etc.)"
        puts "    - Insufficient permissions on the Zoho CRM app"
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

    # Zoho requires credentials in the POST body, not query params
    response = Faraday.post("#{accounts_url}/oauth/v2/token") do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      )
    end

    data = JSON.parse(response.body)

    if data['error']
      puts ""
      puts "ERROR: Token exchange failed"
      puts "Error: #{data['error']}"
      puts "Description: #{data['error_description']}" if data['error_description']
      puts ""
      puts "Common issues:"
      puts "  - 'invalid_client': Check client_id and client_secret are correct"
      puts "  - 'invalid_code': Authorization code expired (they're single-use and expire quickly)"
      puts "  - 'invalid_redirect_uri': Redirect URI must match exactly what's in Zoho console"
      puts ""
      puts "Debug info:"
      puts "  Accounts URL: #{accounts_url}"
      puts "  Client ID: #{client_id[0..10]}...#{client_id[-4..]}"
      puts "  Redirect URI: #{redirect_uri}"
      exit 1
    elsif data['refresh_token']
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
      puts "ERROR: Unexpected response (no refresh_token or error)"
      puts "Response: #{data}"
    end

    puts ""
  end

  desc "Sync a specific user to Zoho CRM (by ID or email)"
  task :sync_user, [:user_identifier] => :environment do |_t, args|
    user_identifier = args[:user_identifier]

    unless user_identifier
      puts "Usage: rake zoho:sync_user[USER_ID_OR_EMAIL]"
      puts ""
      puts "Examples:"
      puts "  rake zoho:sync_user[123]"
      puts "  rake zoho:sync_user[user@example.com]"
      exit 1
    end

    # Try to find user by ID first, then by email
    user = if user_identifier.match?(/^\d+$/)
             Pwb::User.find_by(id: user_identifier)
           else
             Pwb::User.find_by(email: user_identifier)
           end

    unless user
      puts "ERROR: User not found with identifier: #{user_identifier}"
      exit 1
    end

    service = Pwb::Zoho::LeadSyncService.new

    if user.zoho_synced?
      puts "User #{user.id} (#{user.email}) already synced to Zoho (Lead ID: #{user.zoho_lead_id})"
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
