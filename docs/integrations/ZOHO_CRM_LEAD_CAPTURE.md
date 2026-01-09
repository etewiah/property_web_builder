# Zoho CRM Lead Capture Integration

**Purpose:** Capture leads from real estate agents who sign up for PropertyWebBuilder and track them through the sales funnel in Zoho CRM.

**Document Version:** 1.0
**Created:** January 2025
**Status:** Detailed Implementation Plan

---

## Business Objectives

As the tenant_admin (platform owner), you need to:

1. **Capture every signup** - When a real estate agent creates an account, immediately create a Lead in Zoho CRM
2. **Track plan selection** - Know which plan (Starter/Professional/Enterprise) they chose
3. **Monitor trial progress** - See who's actively using the trial vs. dormant
4. **Identify hot leads** - Agents who add properties, customize their site, or send inquiries
5. **Enable follow-up** - Sales team can reach out at the right moment (trial ending, high engagement)

---

## Data Flow: PWB Events to Zoho CRM

### Event 1: New Account Created (Signup Step 1)

**Trigger:** User submits email in signup form
**PWB Location:** `SignupController#start` calls `ProvisioningService.start_signup`

**Zoho Module:** Leads

**Data Captured:**
| PWB Field | Zoho Field | Notes |
|-----------|------------|-------|
| `user.email` | Email | Primary identifier |
| `user.created_at` | Lead Created Time | Timestamp |
| `request.ip` | Lead Source Details | For geo-location |
| `request.referrer` | Source | utm_source if present |
| `'Website Signup'` | Lead Source | Fixed value |
| `'New'` | Lead Status | Initial status |

**Zoho API Call:**
```json
POST /crm/v3/Leads
{
  "data": [{
    "Email": "agent@realty.com",
    "Last_Name": "Unknown",
    "Lead_Source": "Website Signup",
    "Lead_Status": "New",
    "Description": "Signed up for PWB trial",
    "PWB_User_ID": "12345",
    "Signup_IP": "192.168.1.1",
    "UTM_Source": "google",
    "UTM_Medium": "cpc",
    "UTM_Campaign": "real-estate-saas"
  }]
}
```

---

### Event 2: Website Created (Signup Step 2)

**Trigger:** User configures subdomain and site type
**PWB Location:** `SignupController#save_configuration` calls `ProvisioningService.configure_site`

**Zoho Module:** Update existing Lead

**Data Captured:**
| PWB Field | Zoho Field | Notes |
|-----------|------------|-------|
| `website.subdomain` | PWB_Subdomain | Custom field |
| `website.site_type` | Industry | residential/commercial/vacation |
| `plan.display_name` | Plan_Selected | Starter/Professional/Enterprise |
| `plan.price_cents` | Annual_Value | For pipeline value |
| `'Configured'` | Lead_Status | Progress indicator |

**Zoho API Call:**
```json
PUT /crm/v3/Leads/{lead_id}
{
  "data": [{
    "Lead_Status": "Configured",
    "PWB_Subdomain": "coastal-realty",
    "Industry": "Residential Real Estate",
    "Plan_Selected": "Professional",
    "Annual_Value": 3588.00,
    "Trial_Start_Date": "2025-01-09",
    "Trial_End_Date": "2025-02-09"
  }]
}
```

---

### Event 3: Website Goes Live (Email Verified)

**Trigger:** User verifies email, website provisioning completes
**PWB Location:** `ProvisioningService#complete_provisioning` transitions to `live` state

**Zoho Module:** Update Lead, optionally convert to Contact + Account

**Data Captured:**
| PWB Field | Zoho Field | Notes |
|-----------|------------|-------|
| `website.subdomain` | Website | Full URL |
| `website.company_display_name` | Company | If provided |
| `'Active Trial'` | Lead_Status | Verified user |

**Zoho API Call:**
```json
PUT /crm/v3/Leads/{lead_id}
{
  "data": [{
    "Lead_Status": "Active Trial",
    "Website": "https://coastal-realty.pwb.io",
    "Company": "Coastal Realty Group",
    "Email_Verified": true,
    "Verified_At": "2025-01-09T14:30:00Z"
  }]
}
```

---

### Event 4: Plan Selected/Changed

**Trigger:** User selects or upgrades their plan
**PWB Location:** `Subscription` model callbacks

**Zoho Module:** Update Lead, create Deal (opportunity)

**Data Captured:**
| PWB Field | Zoho Field | Notes |
|-----------|------------|-------|
| `plan.display_name` | Plan_Selected | Current plan |
| `plan.price_cents * 12` | Amount | Annual value |
| `subscription.status` | Subscription_Status | trialing/active/etc |
| `subscription.trial_ends_at` | Trial_End_Date | For follow-up timing |

**Zoho API Call (Create Deal):**
```json
POST /crm/v3/Deals
{
  "data": [{
    "Deal_Name": "Coastal Realty - Professional Plan",
    "Stage": "Trial",
    "Amount": 3588.00,
    "Closing_Date": "2025-02-09",
    "Contact_Name": "{contact_id}",
    "Account_Name": "{account_id}",
    "Pipeline": "PWB Subscriptions",
    "PWB_Plan": "Professional",
    "PWB_Website_ID": "12345"
  }]
}
```

---

### Event 5: User Activity (Engagement Signals)

**Trigger:** User performs key actions
**PWB Location:** Various controllers + Ahoy events

**Key Activities to Track:**

| Activity | Engagement Score | Zoho Update |
|----------|-----------------|-------------|
| Added first property | +20 | Note + Lead Score |
| Added 5+ properties | +30 | Lead Status -> "Engaged" |
| Uploaded logo/customized theme | +15 | Note |
| Created additional pages | +10 | Note |
| Received first inquiry | +25 | Note + Lead Status -> "Hot" |
| Logged in 3+ times | +10 | Note |
| Added team member | +20 | Note + User Count |

**Zoho API Call (Add Note):**
```json
POST /crm/v3/Notes
{
  "data": [{
    "Note_Title": "Activity: Added first property",
    "Note_Content": "User added property 'Beachfront Villa' (REF: BV-001) to their website coastal-realty.pwb.io",
    "Parent_Id": "{lead_id}",
    "se_module": "Leads"
  }]
}
```

**Zoho API Call (Update Lead Score):**
```json
PUT /crm/v3/Leads/{lead_id}
{
  "data": [{
    "Lead_Score": 65,
    "Properties_Count": 5,
    "Last_Activity_Date": "2025-01-09T16:45:00Z"
  }]
}
```

---

### Event 6: Trial Ending Soon (3 days before)

**Trigger:** Scheduled job checks `subscription.trial_ends_at`
**PWB Location:** `TrialExpirationJob` (to be created)

**Zoho Module:** Update Lead, trigger workflow

**Data Captured:**
| PWB Field | Zoho Field | Notes |
|-----------|------------|-------|
| `trial_days_remaining` | Trial_Days_Left | 3, 2, 1, 0 |
| `'Trial Ending'` | Lead_Status | Trigger sales outreach |

This enables Zoho Workflows to:
- Send automated email reminders
- Create tasks for sales team
- Trigger SMS via Zoho Campaigns

---

### Event 7: Subscription Activated (Converted to Paying Customer)

**Trigger:** Payment received, subscription status changes to `active`
**PWB Location:** `Subscription#activate` callback

**Zoho Module:** Convert Lead to Contact + Account + Deal (Won)

**Zoho API Call (Convert Lead):**
```json
POST /crm/v3/Leads/{lead_id}/actions/convert
{
  "data": [{
    "overwrite": true,
    "notify_lead_owner": true,
    "notify_new_entity_owner": true,
    "Deals": {
      "Deal_Name": "Coastal Realty - Professional Plan",
      "Stage": "Closed Won",
      "Amount": 3588.00,
      "Closing_Date": "2025-01-09"
    }
  }]
}
```

---

### Event 8: Subscription Canceled/Expired

**Trigger:** User cancels or trial expires without payment
**PWB Location:** `Subscription#cancel` or `Subscription#expire_trial` callbacks

**Zoho Module:** Update Deal to Lost, add reason

**Data Captured:**
| PWB Field | Zoho Field | Notes |
|-----------|------------|-------|
| `subscription.status` | Deal_Stage | Closed Lost |
| `'Trial Expired'` or `'User Canceled'` | Lost_Reason | For analysis |
| `subscription.canceled_at` | Closed_Date | When it happened |

---

## Zoho CRM Custom Fields Required

Create these custom fields in Zoho CRM:

### Leads Module:
| Field Name | API Name | Type | Description |
|------------|----------|------|-------------|
| PWB User ID | PWB_User_ID | Number | Internal user ID |
| PWB Subdomain | PWB_Subdomain | Single Line | e.g., "coastal-realty" |
| Plan Selected | Plan_Selected | Picklist | Starter/Professional/Enterprise |
| Trial Start Date | Trial_Start_Date | Date | When trial began |
| Trial End Date | Trial_End_Date | Date | When trial ends |
| Trial Days Left | Trial_Days_Left | Number | Countdown |
| Properties Count | Properties_Count | Number | How many listings added |
| Last Activity Date | Last_Activity_Date | DateTime | Last engagement |
| Lead Score | Lead_Score | Number | Engagement score (0-100) |
| UTM Source | UTM_Source | Single Line | Marketing attribution |
| UTM Medium | UTM_Medium | Single Line | Marketing attribution |
| UTM Campaign | UTM_Campaign | Single Line | Marketing attribution |
| Email Verified | Email_Verified | Checkbox | Completed signup |

### Deals Module:
| Field Name | API Name | Type | Description |
|------------|----------|------|-------------|
| PWB Plan | PWB_Plan | Picklist | Selected plan |
| PWB Website ID | PWB_Website_ID | Number | Internal website ID |
| Monthly Value | Monthly_Value | Currency | MRR |
| Subscription Status | Subscription_Status | Picklist | trialing/active/canceled |

---

## Implementation Architecture

### Service Class Structure

```
app/services/pwb/zoho/
├── client.rb                 # OAuth token management, HTTP client
├── lead_sync_service.rb      # Lead CRUD operations
├── deal_sync_service.rb      # Deal/Opportunity management
├── activity_tracker.rb       # Notes and activity logging
└── webhook_receiver.rb       # Handle Zoho webhooks (optional)
```

### Background Jobs

```
app/jobs/pwb/zoho/
├── sync_new_signup_job.rb       # Event 1: New signup
├── sync_website_created_job.rb  # Event 2: Website configured
├── sync_website_live_job.rb     # Event 3: Email verified
├── sync_plan_selected_job.rb    # Event 4: Plan chosen
├── sync_activity_job.rb         # Event 5: User actions
├── trial_reminder_job.rb        # Event 6: Trial ending
├── sync_conversion_job.rb       # Event 7: Paid customer
└── sync_cancellation_job.rb     # Event 8: Lost customer
```

### Model Callbacks

```ruby
# app/models/pwb/user.rb
after_create :sync_to_zoho_as_lead

# app/models/pwb/website.rb
after_update :sync_website_to_zoho, if: :provisioning_completed?

# app/models/pwb/subscription.rb
after_commit :sync_subscription_to_zoho

# app/models/pwb/realty_asset.rb (Property)
after_create :track_property_activity_in_zoho
```

---

## Zoho OAuth Setup

### 1. Create Zoho API Console Application

1. Go to: https://api-console.zoho.com/
2. Click "Add Client" -> "Server-based Applications"
3. Configure:
   - Client Name: `PropertyWebBuilder`
   - Homepage URL: `https://yourplatform.com`
   - Authorized Redirect URIs: `https://yourplatform.com/admin/zoho/callback`
4. Note your `Client ID` and `Client Secret`

### 2. Required Scopes

```
ZohoCRM.modules.leads.ALL
ZohoCRM.modules.deals.ALL
ZohoCRM.modules.contacts.ALL
ZohoCRM.modules.accounts.ALL
ZohoCRM.modules.notes.ALL
ZohoCRM.settings.ALL
ZohoCRM.users.READ
```

### 3. Environment Variables

```bash
# config/credentials.yml.enc (encrypted)
zoho:
  client_id: YOUR_CLIENT_ID
  client_secret: YOUR_CLIENT_SECRET
  refresh_token: YOUR_REFRESH_TOKEN  # Obtained during OAuth flow
  api_domain: https://www.zohoapis.com  # or .eu, .in based on datacenter
```

---

## Implementation: Phase 1 (Core Lead Capture)

### Step 1: Create Zoho Client Service

```ruby
# app/services/pwb/zoho/client.rb
module Pwb
  module Zoho
    class Client
      TOKEN_REFRESH_BUFFER = 5.minutes

      class << self
        def instance
          @instance ||= new
        end
      end

      def initialize
        @credentials = Rails.application.credentials.zoho
        @token_cache = ActiveSupport::Cache::MemoryStore.new
      end

      def post(endpoint, body)
        request(:post, endpoint, body)
      end

      def put(endpoint, body)
        request(:put, endpoint, body)
      end

      def get(endpoint, params = {})
        request(:get, endpoint, nil, params)
      end

      private

      def request(method, endpoint, body = nil, params = {})
        response = connection.send(method, endpoint) do |req|
          req.headers['Authorization'] = "Zoho-oauthtoken #{access_token}"
          req.params = params if params.any?
          req.body = body.to_json if body
        end

        handle_response(response)
      end

      def connection
        @connection ||= Faraday.new(url: api_base_url) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
          f.options.timeout = 30
        end
      end

      def api_base_url
        "#{@credentials[:api_domain]}/crm/v3"
      end

      def access_token
        cached = @token_cache.read('zoho_access_token')
        return cached if cached

        refresh_access_token
      end

      def refresh_access_token
        response = Faraday.post("https://accounts.zoho.com/oauth/v2/token") do |req|
          req.params = {
            refresh_token: @credentials[:refresh_token],
            client_id: @credentials[:client_id],
            client_secret: @credentials[:client_secret],
            grant_type: 'refresh_token'
          }
        end

        data = JSON.parse(response.body)

        if data['access_token']
          expires_in = (data['expires_in'] || 3600).to_i - TOKEN_REFRESH_BUFFER.to_i
          @token_cache.write('zoho_access_token', data['access_token'], expires_in: expires_in)
          data['access_token']
        else
          raise "Zoho token refresh failed: #{data['error']}"
        end
      end

      def handle_response(response)
        case response.status
        when 200..299
          response.body
        when 401
          # Token expired, clear cache and retry once
          @token_cache.delete('zoho_access_token')
          raise Zoho::AuthenticationError, "Token expired"
        when 429
          raise Zoho::RateLimitError, "Rate limit exceeded"
        else
          raise Zoho::ApiError, "Zoho API error: #{response.status} - #{response.body}"
        end
      end
    end

    class AuthenticationError < StandardError; end
    class RateLimitError < StandardError; end
    class ApiError < StandardError; end
  end
end
```

### Step 2: Create Lead Sync Service

```ruby
# app/services/pwb/zoho/lead_sync_service.rb
module Pwb
  module Zoho
    class LeadSyncService
      def initialize(client: Client.instance)
        @client = client
      end

      # Event 1: New signup
      def create_lead_from_signup(user, request_info: {})
        payload = {
          data: [{
            Email: user.email,
            Last_Name: extract_name(user.email),
            Lead_Source: 'Website Signup',
            Lead_Status: 'New',
            PWB_User_ID: user.id,
            Signup_IP: request_info[:ip],
            UTM_Source: request_info[:utm_source],
            UTM_Medium: request_info[:utm_medium],
            UTM_Campaign: request_info[:utm_campaign],
            Description: "Signed up for PWB trial on #{Time.current.strftime('%Y-%m-%d %H:%M')}"
          }]
        }

        response = @client.post('/Leads', payload)

        if response.dig('data', 0, 'details', 'id')
          zoho_lead_id = response.dig('data', 0, 'details', 'id')
          store_zoho_id(user, zoho_lead_id)
          zoho_lead_id
        end
      end

      # Event 2: Website configured
      def update_lead_website_created(user, website, plan)
        zoho_id = get_zoho_id(user)
        return create_lead_from_signup(user) unless zoho_id

        payload = {
          data: [{
            Lead_Status: 'Configured',
            PWB_Subdomain: website.subdomain,
            Industry: map_site_type(website.site_type),
            Plan_Selected: plan&.display_name || 'Starter',
            Annual_Value: calculate_annual_value(plan),
            Trial_Start_Date: Date.current.iso8601,
            Trial_End_Date: (Date.current + plan&.trial_days.to_i.days).iso8601
          }]
        }

        @client.put("/Leads/#{zoho_id}", payload)
      end

      # Event 3: Email verified, site is live
      def update_lead_website_live(user, website)
        zoho_id = get_zoho_id(user)
        return unless zoho_id

        payload = {
          data: [{
            Lead_Status: 'Active Trial',
            Website: "https://#{website.subdomain}.#{ENV['PWB_BASE_DOMAIN']}",
            Company: website.company_display_name.presence,
            Email_Verified: true,
            Verified_At: Time.current.iso8601
          }]
        }

        @client.put("/Leads/#{zoho_id}", payload)
      end

      # Event 5: Track activity
      def log_activity(user, activity_type, details = {})
        zoho_id = get_zoho_id(user)
        return unless zoho_id

        # Add note
        note_payload = {
          data: [{
            Note_Title: "Activity: #{activity_type}",
            Note_Content: format_activity_note(activity_type, details),
            Parent_Id: zoho_id,
            se_module: 'Leads'
          }]
        }
        @client.post('/Notes', note_payload)

        # Update lead score and counts
        update_lead_engagement(zoho_id, activity_type, details)
      end

      # Event 6: Trial ending
      def update_trial_ending(user, days_remaining)
        zoho_id = get_zoho_id(user)
        return unless zoho_id

        payload = {
          data: [{
            Lead_Status: 'Trial Ending',
            Trial_Days_Left: days_remaining,
            Last_Activity_Date: Time.current.iso8601
          }]
        }

        @client.put("/Leads/#{zoho_id}", payload)
      end

      # Event 7: Convert to customer
      def convert_lead_to_customer(user, subscription)
        zoho_id = get_zoho_id(user)
        return unless zoho_id

        payload = {
          data: [{
            overwrite: true,
            notify_lead_owner: true,
            Deals: {
              Deal_Name: "#{user.website&.company_display_name || user.email} - #{subscription.plan.display_name}",
              Stage: 'Closed Won',
              Amount: calculate_annual_value(subscription.plan),
              Closing_Date: Date.current.iso8601,
              PWB_Plan: subscription.plan.display_name,
              PWB_Website_ID: subscription.website_id
            }
          }]
        }

        @client.post("/Leads/#{zoho_id}/actions/convert", payload)
      end

      # Event 8: Lost customer
      def mark_lead_lost(user, reason)
        zoho_id = get_zoho_id(user)
        return unless zoho_id

        payload = {
          data: [{
            Lead_Status: 'Lost',
            Lost_Reason: reason,
            Last_Activity_Date: Time.current.iso8601
          }]
        }

        @client.put("/Leads/#{zoho_id}", payload)
      end

      private

      def extract_name(email)
        email.split('@').first.gsub(/[._]/, ' ').titleize
      end

      def map_site_type(site_type)
        {
          'residential' => 'Residential Real Estate',
          'commercial' => 'Commercial Real Estate',
          'vacation_rental' => 'Vacation Rentals',
          'property_management' => 'Property Management'
        }[site_type] || 'Real Estate'
      end

      def calculate_annual_value(plan)
        return 0 unless plan
        monthly = plan.price_cents / 100.0
        plan.billing_interval == 'year' ? monthly : monthly * 12
      end

      def store_zoho_id(user, zoho_id)
        user.update_column(:metadata, (user.metadata || {}).merge('zoho_lead_id' => zoho_id))
      end

      def get_zoho_id(user)
        user.metadata&.dig('zoho_lead_id')
      end

      def format_activity_note(activity_type, details)
        case activity_type
        when 'property_added'
          "Added property: #{details[:title]} (REF: #{details[:reference]})"
        when 'logo_uploaded'
          "Uploaded company logo - customizing their site"
        when 'page_created'
          "Created new page: #{details[:page_title]}"
        when 'inquiry_received'
          "Received first customer inquiry - site is generating leads!"
        when 'team_member_added'
          "Added team member: #{details[:email]}"
        else
          "Activity: #{activity_type}"
        end
      end

      def update_lead_engagement(zoho_id, activity_type, details)
        score_delta = {
          'property_added' => 10,
          'first_property' => 20,
          'five_properties' => 30,
          'logo_uploaded' => 15,
          'page_created' => 10,
          'inquiry_received' => 25,
          'team_member_added' => 20
        }[activity_type] || 5

        # Get current score and update
        lead = @client.get("/Leads/#{zoho_id}")
        current_score = lead.dig('data', 0, 'Lead_Score') || 0

        update_payload = {
          data: [{
            Lead_Score: [current_score + score_delta, 100].min,
            Last_Activity_Date: Time.current.iso8601
          }]
        }

        # Add properties count if relevant
        if activity_type.include?('property')
          update_payload[:data][0][:Properties_Count] = details[:total_count]
        end

        # Update status to Engaged or Hot based on score
        new_score = current_score + score_delta
        if new_score >= 70
          update_payload[:data][0][:Lead_Status] = 'Hot'
        elsif new_score >= 40
          update_payload[:data][0][:Lead_Status] = 'Engaged'
        end

        @client.put("/Leads/#{zoho_id}", update_payload)
      end
    end
  end
end
```

### Step 3: Create Background Jobs

```ruby
# app/jobs/pwb/zoho/sync_new_signup_job.rb
module Pwb
  module Zoho
    class SyncNewSignupJob < ApplicationJob
      queue_as :default

      retry_on Zoho::RateLimitError, wait: 1.minute, attempts: 3
      retry_on Zoho::ApiError, wait: 5.seconds, attempts: 2
      discard_on Zoho::AuthenticationError # Alert and fix credentials

      def perform(user_id, request_info = {})
        return unless zoho_enabled?

        user = ::Pwb::User.find(user_id)
        LeadSyncService.new.create_lead_from_signup(user, request_info: request_info)

        Rails.logger.info "[Zoho] Created lead for user #{user.id}"
      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn "[Zoho] User #{user_id} not found, skipping"
      end

      private

      def zoho_enabled?
        Rails.application.credentials.dig(:zoho, :client_id).present?
      end
    end
  end
end
```

### Step 4: Add Model Callbacks

```ruby
# Add to app/models/pwb/user.rb
class Pwb::User < ApplicationRecord
  after_create_commit :sync_to_zoho_crm

  private

  def sync_to_zoho_crm
    return unless onboarding_state == 'lead'

    Zoho::SyncNewSignupJob.perform_later(
      id,
      {
        ip: Current.request_ip,
        utm_source: Current.utm_params&.dig('utm_source'),
        utm_medium: Current.utm_params&.dig('utm_medium'),
        utm_campaign: Current.utm_params&.dig('utm_campaign')
      }
    )
  end
end
```

---

## Sales Team Workflows in Zoho

### Recommended Lead Views

1. **New Signups Today** - Leads where `Created_Time = TODAY` and `Lead_Status = 'New'`
2. **Trial Ending This Week** - Leads where `Trial_End_Date` is within 7 days
3. **Hot Leads** - Leads where `Lead_Score >= 70`
4. **Dormant Trials** - Leads where `Lead_Status = 'Active Trial'` and `Last_Activity_Date < 7 days ago`
5. **Ready to Convert** - Leads where `Properties_Count >= 5` and `Lead_Status = 'Engaged'`

### Automated Workflows

1. **Welcome Email** - Trigger when Lead_Status = 'New'
2. **Getting Started Tips** - Trigger 2 days after signup if no activity
3. **Trial Ending Reminder** - Trigger when Trial_Days_Left = 3
4. **Last Chance Offer** - Trigger when Trial_Days_Left = 1
5. **Win-Back Campaign** - Trigger 30 days after Lead_Status = 'Lost'

### Task Assignments

- **New Hot Lead** -> Create task for sales rep
- **Trial Ending + High Score** -> Create urgent task for sales manager
- **Inquiry Received** -> Create follow-up task

---

## Testing Checklist

### Manual Tests

- [ ] Create test signup, verify Lead appears in Zoho
- [ ] Complete signup flow, verify Lead updates with subdomain/plan
- [ ] Verify email, check Lead_Status = 'Active Trial'
- [ ] Add property, verify Note created and score updated
- [ ] Simulate trial ending, verify Trial_Days_Left updates
- [ ] Complete payment, verify Lead converts to Contact + Account + Deal
- [ ] Cancel subscription, verify Lost status

### Automated Tests

```ruby
# spec/services/pwb/zoho/lead_sync_service_spec.rb
RSpec.describe Pwb::Zoho::LeadSyncService do
  describe '#create_lead_from_signup' do
    it 'creates lead in Zoho and stores ID' do
      user = create(:user, email: 'test@example.com')

      VCR.use_cassette('zoho_create_lead') do
        service.create_lead_from_signup(user)
      end

      expect(user.reload.metadata['zoho_lead_id']).to be_present
    end
  end
end
```

---

## Monitoring & Alerts

### Key Metrics to Track

1. **Sync Success Rate** - % of signups that create Leads successfully
2. **API Error Rate** - Track Zoho API failures
3. **Token Refresh Health** - Monitor OAuth token lifecycle
4. **Lead Data Quality** - Check for missing required fields

### Alert Conditions

- Zoho API returning 401 (auth issues) -> PagerDuty alert
- Sync queue depth > 100 -> Slack notification
- Daily sync failures > 10% -> Email to admin

---

## Next Steps

1. **Create Zoho API Console app** and obtain credentials
2. **Create custom fields** in Zoho CRM Leads module
3. **Implement Client service** with OAuth handling
4. **Add LeadSyncService** with core methods
5. **Add jobs and callbacks** to trigger syncs
6. **Test with sandbox** before production
7. **Set up Zoho workflows** for sales team automation
8. **Monitor and iterate** based on sales team feedback
