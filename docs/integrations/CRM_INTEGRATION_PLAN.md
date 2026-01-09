# CRM Integration Plan: Zoho CRM & Zendesk

**Document Version:** 1.0  
**Created:** January 8, 2025  
**Status:** Planning

## Executive Summary

This document outlines integration options and implementation plan for connecting PropertyWebBuilder (PWB) with third-party CRM systems, specifically Zoho CRM and Zendesk. The goal is to enable seamless data flow between PWB's contact/inquiry management and external CRM platforms.

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Integration Options](#integration-options)
3. [Recommended Approach](#recommended-approach)
4. [Detailed Implementation Plan](#detailed-implementation-plan)
5. [Technical Specifications](#technical-specifications)
6. [Security Considerations](#security-considerations)
7. [Testing Strategy](#testing-strategy)
8. [Rollout Plan](#rollout-plan)

---

## Current State Analysis

### Existing PWB Components

PropertyWebBuilder has robust internal systems that map well to CRM concepts:

#### 1. Contact Management (`Pwb::Contact`)
**Location:** `app/models/pwb/contact.rb`

**Features:**
- Full contact information (name, email, phone, addresses)
- Social media IDs (Facebook, LinkedIn, Twitter, Skype)
- Documentation/ID tracking
- Message history tracking
- Tenant-scoped (each website has separate contacts)

**Key Fields:**
```ruby
- first_name, last_name, title
- primary_email, other_email
- primary_phone_number, other_phone_number
- primary_address_id, secondary_address_id
- website_id (tenant isolation)
- details (JSON - for storing integration metadata)
```

#### 2. Message/Inquiry System (`Pwb::Message`)
**Location:** `app/models/pwb/message.rb`

**Features:**
- Property inquiry tracking
- Contact association
- Message threading
- Read/unread status
- Tenant-scoped

**Use Cases:**
- Property viewing requests
- General inquiries
- Contact form submissions
- Lead generation

#### 3. Support Ticketing (`Pwb::SupportTicket`)
**Location:** `app/models/pwb/support_ticket.rb`

**Features:**
- Full ticketing system with SLA tracking
- Priority levels (low, normal, high, urgent)
- Status workflow (open → in_progress → resolved → closed)
- Assignment to support agents
- First response and resolution tracking
- Category tagging

**SLA Tracking:**
```ruby
SLA_RESPONSE_HOURS = {
  "low" => 48,
  "normal" => 24,
  "high" => 8,
  "urgent" => 2
}

SLA_RESOLUTION_HOURS = {
  "low" => 168,    # 7 days
  "normal" => 72,  # 3 days
  "high" => 24,    # 1 day
  "urgent" => 8    # 8 hours
}
```

#### 4. Multi-Tenant Architecture
- Each `Pwb::Website` is a separate tenant
- Data is isolated by `website_id`
- Sharding support for scale
- Per-tenant configuration via `Pwb::TenantSettings`

### Integration Precedent

PWB already has integration patterns:

**Twilio Integration:**
- Location: `docs/integrations/TWILIO_INTEGRATION_PLAN.md`
- Pattern: Per-tenant API credentials
- Graceful degradation when not configured
- Configuration via environment variables

**External Feeds:**
- MLS/property feed integrations
- Per-tenant feed configuration
- Polling and webhook support

---

## Integration Options

### Option 1: Webhook-Based Push Integration ⭐ (Recommended)

**Description:** PWB sends data to CRM platforms in real-time via webhooks when events occur.

**Pros:**
- Real-time data sync
- Simple to implement
- Low resource usage
- Works with both Zoho and Zendesk
- Each tenant can configure their own endpoints

**Cons:**
- One-way sync (PWB → CRM)
- Requires CRM platform to accept webhooks
- Need retry logic for failed sends

**Best For:**
- Keeping CRM updated with new leads
- Support ticket creation in Zendesk
- Real-time notifications

### Option 2: API Polling Integration

**Description:** PWB periodically fetches updates from CRM platforms.

**Pros:**
- Two-way sync possible
- Can import existing CRM data
- Works with any API

**Cons:**
- Delayed updates (polling interval)
- Higher resource usage
- More complex error handling
- API rate limits

**Best For:**
- Importing historical data
- Syncing CRM updates back to PWB
- Batch operations

### Option 3: OAuth + Deep Integration

**Description:** Full bi-directional integration with OAuth authentication.

**Pros:**
- Secure credential management
- Two-way sync
- User-specific permissions
- Professional appearance

**Cons:**
- Complex implementation
- Requires OAuth app registration
- Maintenance overhead
- Per-platform implementation

**Best For:**
- Enterprise customers
- Full feature parity
- Long-term strategic integrations

### Option 4: Zapier/Make.com (No-Code)

**Description:** Expose webhook endpoints; users configure integrations themselves.

**Pros:**
- Zero maintenance
- Works with 1000+ apps
- User controls their own data flow
- Fastest to implement

**Cons:**
- Requires users to pay for Zapier/Make
- Less control over user experience
- No built-in UI

**Best For:**
- MVP/quick launch
- Power users
- Supporting many platforms

---

## Recommended Approach

**Hybrid Strategy: Option 1 (Webhooks) + Option 4 (Zapier)**

### Phase 1: Webhook Infrastructure (Weeks 1-2)
Build generic webhook system that works for any platform.

### Phase 2: Zoho CRM Direct Integration (Weeks 3-4)
First-class Zoho integration using webhooks.

### Phase 3: Zendesk Direct Integration (Weeks 5-6)
First-class Zendesk integration.

### Phase 4: Zapier Support (Week 7)
Document endpoints for self-service integration.

---

## Detailed Implementation Plan

### Phase 1: Webhook Infrastructure

#### 1.1 Create Integration Model

**File:** `app/models/pwb/integration.rb`

```ruby
# == Schema Information
#
# Table name: pwb_integrations
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE)
#  config          :jsonb            not null
#  last_error      :text
#  last_synced_at  :datetime
#  name            :string           not null
#  platform        :string(50)      not null (zoho_crm, zendesk, custom)
#  webhook_url     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  website_id      :bigint           not null
#
# Indexes
#
#  index_pwb_integrations_on_website_id              (website_id)
#  index_pwb_integrations_on_website_id_and_platform (website_id,platform)
#  index_pwb_integrations_on_active                  (active)

class Pwb::Integration < ApplicationRecord
  belongs_to :website
  
  encrypts :config  # Store API keys securely
  
  validates :platform, presence: true,
    inclusion: { in: %w[zoho_crm zendesk custom] }
  validates :name, presence: true
  validates :webhook_url, url: true, if: -> { platform == 'custom' }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  
  # Platform-specific configurations
  def zoho_crm?
    platform == 'zoho_crm'
  end
  
  def zendesk?
    platform == 'zendesk'
  end
  
  def custom?
    platform == 'custom'
  end
end
```

**Migration:**
```ruby
# db/migrate/YYYYMMDDHHMMSS_create_pwb_integrations.rb
class CreatePwbIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_integrations do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :platform, null: false, limit: 50
      t.string :name, null: false
      t.string :webhook_url
      t.jsonb :config, null: false, default: {}
      t.boolean :active, default: true
      t.datetime :last_synced_at
      t.text :last_error
      
      t.timestamps
    end
    
    add_index :pwb_integrations, [:website_id, :platform]
    add_index :pwb_integrations, :active
  end
end
```

#### 1.2 Create Integration Service Base Class

**File:** `app/services/pwb/integrations/base_service.rb`

```ruby
module Pwb
  module Integrations
    class BaseService
      attr_reader :integration, :website
      
      def initialize(integration)
        @integration = integration
        @website = integration.website
      end
      
      # Override in subclasses
      def sync_contact(contact)
        raise NotImplementedError
      end
      
      def sync_message(message)
        raise NotImplementedError
      end
      
      def sync_support_ticket(ticket)
        raise NotImplementedError
      end
      
      protected
      
      def http_client
        @http_client ||= Faraday.new do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
          f.options.timeout = 30
          f.options.open_timeout = 10
        end
      end
      
      def handle_error(error)
        Rails.logger.error "[Integration #{integration.id}] #{error.class}: #{error.message}"
        integration.update(
          last_error: "#{error.class}: #{error.message}",
          last_synced_at: Time.current
        )
      end
      
      def record_success
        integration.update(
          last_error: nil,
          last_synced_at: Time.current
        )
      end
    end
  end
end
```

#### 1.3 Create Integration Job

**File:** `app/jobs/pwb/integration_sync_job.rb`

```ruby
module Pwb
  class IntegrationSyncJob < ApplicationJob
    queue_as :default
    
    retry_on Faraday::TimeoutError, wait: :exponentially_longer, attempts: 3
    retry_on Faraday::ConnectionFailed, wait: 5.minutes, attempts: 2
    
    def perform(integration_id, action, record_type, record_id)
      integration = Integration.find(integration_id)
      return unless integration.active?
      
      record = find_record(record_type, record_id)
      return unless record
      
      service = service_for_integration(integration)
      
      case action
      when 'create', 'update'
        sync_record(service, record_type, record)
      when 'delete'
        # Handle deletions if needed
      end
    rescue => e
      Rails.logger.error "[IntegrationSyncJob] Failed: #{e.message}"
      raise
    end
    
    private
    
    def find_record(record_type, record_id)
      case record_type
      when 'contact'
        Pwb::Contact.find_by(id: record_id)
      when 'message'
        Pwb::Message.find_by(id: record_id)
      when 'support_ticket'
        Pwb::SupportTicket.find_by(id: record_id)
      end
    end
    
    def service_for_integration(integration)
      case integration.platform
      when 'zoho_crm'
        Integrations::ZohoCrmService.new(integration)
      when 'zendesk'
        Integrations::ZendeskService.new(integration)
      when 'custom'
        Integrations::WebhookService.new(integration)
      end
    end
    
    def sync_record(service, record_type, record)
      case record_type
      when 'contact'
        service.sync_contact(record)
      when 'message'
        service.sync_message(record)
      when 'support_ticket'
        service.sync_support_ticket(record)
      end
    end
  end
end
```

#### 1.4 Add Integration Concern

**File:** `app/models/concerns/pwb/integrable.rb`

```ruby
module Pwb
  module Integrable
    extend ActiveSupport::Concern
    
    included do
      after_create :sync_to_integrations
      after_update :sync_to_integrations
    end
    
    private
    
    def sync_to_integrations
      return unless website.present?
      
      website.integrations.active.each do |integration|
        IntegrationSyncJob.perform_later(
          integration.id,
          'create',
          self.class.name.demodulize.underscore,
          id
        )
      end
    end
  end
end
```

**Update Models:**
```ruby
# app/models/pwb/contact.rb
class Pwb::Contact < ApplicationRecord
  include Integrable
  # ... existing code ...
end

# app/models/pwb/message.rb
class Pwb::Message < ApplicationRecord
  include Integrable
  # ... existing code ...
end

# app/models/pwb/support_ticket.rb
class Pwb::SupportTicket < ApplicationRecord
  include Integrable
  # ... existing code ...
end
```

### Phase 2: Zoho CRM Integration

#### 2.1 Zoho CRM Service

**File:** `app/services/pwb/integrations/zoho_crm_service.rb`

```ruby
module Pwb
  module Integrations
    class ZohoCrmService < BaseService
      ZOHO_API_BASE = "https://www.zohoapis.com/crm/v3"
      
      def sync_contact(contact)
        payload = build_contact_payload(contact)
        
        response = http_client.post("#{ZOHO_API_BASE}/Contacts") do |req|
          req.headers['Authorization'] = "Zoho-oauthtoken #{access_token}"
          req.body = { data: [payload] }
        end
        
        if response.success?
          store_zoho_id(contact, response.body.dig('data', 0, 'details', 'id'))
          record_success
        else
          handle_error(StandardError.new(response.body['message']))
        end
      rescue => e
        handle_error(e)
      end
      
      def sync_message(message)
        # Convert message to Zoho Lead or Note
        contact = message.contact
        return unless contact
        
        # Create as Lead if new contact, or Note if existing
        if contact_has_zoho_id?(contact)
          create_note(message)
        else
          create_lead(message)
        end
      end
      
      def sync_support_ticket(ticket)
        # Map to Zoho Cases module
        payload = {
          Subject: ticket.subject,
          Description: ticket.description,
          Status: map_status(ticket.status),
          Priority: map_priority(ticket.priority),
          Email: ticket.creator.email,
          Product_Name: website.subdomain
        }
        
        response = http_client.post("#{ZOHO_API_BASE}/Cases") do |req|
          req.headers['Authorization'] = "Zoho-oauthtoken #{access_token}"
          req.body = { data: [payload] }
        end
        
        if response.success?
          store_zoho_id(ticket, response.body.dig('data', 0, 'details', 'id'))
          record_success
        end
      rescue => e
        handle_error(e)
      end
      
      private
      
      def access_token
        # Get from integration config or refresh if needed
        token = integration.config['access_token']
        
        if token_expired?
          token = refresh_access_token
        end
        
        token
      end
      
      def refresh_access_token
        response = http_client.post("https://accounts.zoho.com/oauth/v2/token") do |req|
          req.params = {
            refresh_token: integration.config['refresh_token'],
            client_id: integration.config['client_id'],
            client_secret: integration.config['client_secret'],
            grant_type: 'refresh_token'
          }
        end
        
        if response.success?
          new_token = response.body['access_token']
          integration.update(
            config: integration.config.merge(
              'access_token' => new_token,
              'token_expires_at' => Time.current + response.body['expires_in'].seconds
            )
          )
          new_token
        else
          raise "Failed to refresh Zoho token: #{response.body}"
        end
      end
      
      def token_expired?
        expires_at = integration.config['token_expires_at']
        return true unless expires_at
        
        Time.parse(expires_at) < 5.minutes.from_now
      end
      
      def build_contact_payload(contact)
        {
          First_Name: contact.first_name,
          Last_Name: contact.last_name || 'Unknown',
          Email: contact.primary_email,
          Phone: contact.primary_phone_number,
          Mobile: contact.other_phone_number,
          Mailing_Street: contact.street_address,
          Mailing_City: contact.city,
          Mailing_Zip: contact.postal_code,
          Description: "Imported from #{website.subdomain}"
        }
      end
      
      def create_lead(message)
        contact = message.contact
        property = message.prop
        
        payload = {
          First_Name: contact.first_name,
          Last_Name: contact.last_name || 'Unknown',
          Email: contact.primary_email,
          Phone: contact.primary_phone_number,
          Company: website.subdomain,
          Lead_Source: 'Website Inquiry',
          Description: message.message,
          Property_Reference: property&.reference
        }
        
        response = http_client.post("#{ZOHO_API_BASE}/Leads") do |req|
          req.headers['Authorization'] = "Zoho-oauthtoken #{access_token}"
          req.body = { data: [payload] }
        end
        
        if response.success?
          record_success
        end
      end
      
      def create_note(message)
        zoho_contact_id = message.contact.details['zoho_id']
        
        payload = {
          Note_Title: "Property Inquiry - #{message.created_at.strftime('%Y-%m-%d')}",
          Note_Content: message.message,
          Parent_Id: zoho_contact_id,
          se_module: "Contacts"
        }
        
        response = http_client.post("#{ZOHO_API_BASE}/Notes") do |req|
          req.headers['Authorization'] = "Zoho-oauthtoken #{access_token}"
          req.body = { data: [payload] }
        end
      end
      
      def store_zoho_id(record, zoho_id)
        details = record.details || {}
        details['zoho_id'] = zoho_id
        record.update_column(:details, details)
      end
      
      def contact_has_zoho_id?(contact)
        contact.details&.dig('zoho_id').present?
      end
      
      def map_status(status)
        {
          'open' => 'Open',
          'in_progress' => 'In Progress',
          'waiting_on_customer' => 'Waiting for Input',
          'resolved' => 'Closed',
          'closed' => 'Closed'
        }[status] || 'Open'
      end
      
      def map_priority(priority)
        {
          'low' => 'Low',
          'normal' => 'Medium',
          'high' => 'High',
          'urgent' => 'Highest'
        }[priority] || 'Medium'
      end
    end
  end
end
```

#### 2.2 Zoho OAuth Controller

**File:** `app/controllers/tenant_admin/integrations/zoho_oauth_controller.rb`

```ruby
module TenantAdmin
  module Integrations
    class ZohoOauthController < TenantAdminController
      def authorize
        redirect_to zoho_authorization_url, allow_other_host: true
      end
      
      def callback
        code = params[:code]
        
        response = exchange_code_for_token(code)
        
        if response.success?
          create_or_update_integration(response.body)
          redirect_to tenant_admin_integrations_path,
            notice: 'Zoho CRM connected successfully!'
        else
          redirect_to tenant_admin_integrations_path,
            alert: 'Failed to connect Zoho CRM'
        end
      end
      
      private
      
      def zoho_authorization_url
        params = {
          client_id: ENV['ZOHO_CLIENT_ID'],
          redirect_uri: zoho_callback_url,
          scope: 'ZohoCRM.modules.ALL,ZohoCRM.settings.ALL',
          response_type: 'code',
          access_type: 'offline'
        }
        
        "https://accounts.zoho.com/oauth/v2/auth?#{params.to_query}"
      end
      
      def exchange_code_for_token(code)
        Faraday.post("https://accounts.zoho.com/oauth/v2/token") do |req|
          req.params = {
            code: code,
            client_id: ENV['ZOHO_CLIENT_ID'],
            client_secret: ENV['ZOHO_CLIENT_SECRET'],
            redirect_uri: zoho_callback_url,
            grant_type: 'authorization_code'
          }
        end
      end
      
      def create_or_update_integration(token_data)
        integration = current_website.integrations.find_or_initialize_by(
          platform: 'zoho_crm'
        )
        
        integration.assign_attributes(
          name: 'Zoho CRM',
          active: true,
          config: {
            access_token: token_data['access_token'],
            refresh_token: token_data['refresh_token'],
            token_expires_at: Time.current + token_data['expires_in'].seconds,
            client_id: ENV['ZOHO_CLIENT_ID'],
            client_secret: ENV['ZOHO_CLIENT_SECRET'],
            api_domain: token_data['api_domain']
          }
        )
        
        integration.save!
      end
      
      def zoho_callback_url
        tenant_admin_integrations_zoho_callback_url
      end
    end
  end
end
```

### Phase 3: Zendesk Integration

#### 3.1 Zendesk Service

**File:** `app/services/pwb/integrations/zendesk_service.rb`

```ruby
module Pwb
  module Integrations
    class ZendeskService < BaseService
      def sync_contact(contact)
        # Create or update Zendesk user
        payload = {
          user: {
            name: contact.display_name,
            email: contact.primary_email,
            phone: contact.primary_phone_number,
            user_fields: {
              website: website.subdomain,
              pwb_contact_id: contact.id
            }
          }
        }
        
        response = http_client.post("#{zendesk_url}/api/v2/users/create_or_update") do |req|
          req.headers['Authorization'] = auth_header
          req.body = payload
        end
        
        if response.success?
          store_zendesk_id(contact, response.body.dig('user', 'id'))
          record_success
        else
          handle_error(StandardError.new(response.body['error']))
        end
      rescue => e
        handle_error(e)
      end
      
      def sync_message(message)
        # Create Zendesk ticket for property inquiry
        contact = message.contact
        return unless contact
        
        payload = {
          ticket: {
            subject: "Property Inquiry - #{message.prop&.reference}",
            comment: {
              body: build_message_body(message)
            },
            requester: {
              name: contact.display_name,
              email: contact.primary_email
            },
            tags: ['property_inquiry', website.subdomain],
            custom_fields: [
              { id: custom_field_id('property_reference'), value: message.prop&.reference }
            ]
          }
        }
        
        response = http_client.post("#{zendesk_url}/api/v2/tickets") do |req|
          req.headers['Authorization'] = auth_header
          req.body = payload
        end
        
        if response.success?
          store_zendesk_id(message, response.body.dig('ticket', 'id'))
          record_success
        end
      rescue => e
        handle_error(e)
      end
      
      def sync_support_ticket(ticket)
        payload = {
          ticket: {
            subject: ticket.subject,
            comment: {
              body: ticket.description
            },
            requester_id: get_zendesk_user_id(ticket.creator),
            priority: map_priority(ticket.priority),
            status: map_status(ticket.status),
            tags: ['pwb_support', website.subdomain],
            custom_fields: [
              { id: custom_field_id('ticket_number'), value: ticket.ticket_number },
              { id: custom_field_id('pwb_website'), value: website.subdomain }
            ]
          }
        }
        
        response = http_client.post("#{zendesk_url}/api/v2/tickets") do |req|
          req.headers['Authorization'] = auth_header
          req.body = payload
        end
        
        if response.success?
          zendesk_id = response.body.dig('ticket', 'id')
          store_zendesk_id(ticket, zendesk_id)
          
          # Set up two-way sync
          setup_webhook_for_ticket(zendesk_id, ticket.id)
          record_success
        end
      rescue => e
        handle_error(e)
      end
      
      private
      
      def zendesk_url
        "https://#{integration.config['subdomain']}.zendesk.com"
      end
      
      def auth_header
        email = integration.config['email']
        api_token = integration.config['api_token']
        "Basic #{Base64.strict_encode64("#{email}/token:#{api_token}")}"
      end
      
      def build_message_body(message)
        body = message.message
        
        if message.prop
          property = message.prop
          body += "\n\n---\n"
          body += "Property: #{property.title}\n"
          body += "Reference: #{property.reference}\n"
          body += "Price: #{property.price}\n"
          body += "Link: #{property_url(property)}\n"
        end
        
        body
      end
      
      def property_url(property)
        "https://#{website.subdomain}.#{ENV['BASE_DOMAIN']}/properties/#{property.slug}"
      end
      
      def get_zendesk_user_id(user)
        # Look up or create Zendesk user
        zendesk_id = user.details&.dig('zendesk_id')
        return zendesk_id if zendesk_id
        
        # Create user in Zendesk
        response = http_client.post("#{zendesk_url}/api/v2/users") do |req|
          req.headers['Authorization'] = auth_header
          req.body = {
            user: {
              name: user.email.split('@').first,
              email: user.email
            }
          }
        end
        
        if response.success?
          zendesk_id = response.body.dig('user', 'id')
          user.update_column(:details, (user.details || {}).merge('zendesk_id' => zendesk_id))
          zendesk_id
        end
      end
      
      def store_zendesk_id(record, zendesk_id)
        details = record.details || {}
        details['zendesk_id'] = zendesk_id
        record.update_column(:details, details)
      end
      
      def custom_field_id(field_name)
        integration.config.dig('custom_fields', field_name)
      end
      
      def setup_webhook_for_ticket(zendesk_id, pwb_ticket_id)
        # Store mapping for incoming webhook updates
        Rails.cache.write(
          "zendesk_ticket_mapping:#{zendesk_id}",
          pwb_ticket_id,
          expires_in: 1.year
        )
      end
      
      def map_priority(priority)
        {
          'low' => 'low',
          'normal' => 'normal',
          'high' => 'high',
          'urgent' => 'urgent'
        }[priority] || 'normal'
      end
      
      def map_status(status)
        {
          'open' => 'new',
          'in_progress' => 'open',
          'waiting_on_customer' => 'pending',
          'resolved' => 'solved',
          'closed' => 'closed'
        }[status] || 'new'
      end
    end
  end
end
```

#### 3.2 Zendesk Webhook Receiver

**File:** `app/controllers/webhooks/zendesk_controller.rb`

```ruby
module Webhooks
  class ZendeskController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_zendesk_signature
    
    def ticket_update
      zendesk_ticket_id = params[:ticket_id]
      status = params[:status]
      
      pwb_ticket_id = Rails.cache.read("zendesk_ticket_mapping:#{zendesk_ticket_id}")
      return head :ok unless pwb_ticket_id
      
      ticket = Pwb::SupportTicket.find_by(id: pwb_ticket_id)
      return head :ok unless ticket
      
      # Update PWB ticket status based on Zendesk update
      new_status = map_zendesk_status(status)
      ticket.update(status: new_status) if new_status
      
      head :ok
    end
    
    private
    
    def verify_zendesk_signature
      # Verify webhook came from Zendesk
      # Implementation depends on Zendesk webhook security setup
    end
    
    def map_zendesk_status(zendesk_status)
      {
        'new' => 'open',
        'open' => 'in_progress',
        'pending' => 'waiting_on_customer',
        'solved' => 'resolved',
        'closed' => 'closed'
      }[zendesk_status]
    end
  end
end
```

### Phase 4: Custom Webhook Service

**File:** `app/services/pwb/integrations/webhook_service.rb`

```ruby
module Pwb
  module Integrations
    class WebhookService < BaseService
      def sync_contact(contact)
        send_webhook('contact.created', contact_payload(contact))
      end
      
      def sync_message(message)
        send_webhook('message.created', message_payload(message))
      end
      
      def sync_support_ticket(ticket)
        send_webhook('ticket.created', ticket_payload(ticket))
      end
      
      private
      
      def send_webhook(event_type, payload)
        response = http_client.post(integration.webhook_url) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers['X-PWB-Event'] = event_type
          req.headers['X-PWB-Signature'] = generate_signature(payload)
          req.body = payload
        end
        
        if response.success?
          record_success
        else
          handle_error(StandardError.new("Webhook failed: #{response.status}"))
        end
      rescue => e
        handle_error(e)
      end
      
      def generate_signature(payload)
        secret = integration.config['webhook_secret']
        return nil unless secret
        
        OpenSSL::HMAC.hexdigest('SHA256', secret, payload.to_json)
      end
      
      def contact_payload(contact)
        {
          event: 'contact.created',
          website: website.subdomain,
          timestamp: Time.current.iso8601,
          data: {
            id: contact.id,
            first_name: contact.first_name,
            last_name: contact.last_name,
            email: contact.primary_email,
            phone: contact.primary_phone_number,
            created_at: contact.created_at
          }
        }
      end
      
      def message_payload(message)
        {
          event: 'message.created',
          website: website.subdomain,
          timestamp: Time.current.iso8601,
          data: {
            id: message.id,
            contact_id: message.contact_id,
            contact_name: message.contact&.display_name,
            contact_email: message.contact&.primary_email,
            message: message.message,
            property_reference: message.prop&.reference,
            property_title: message.prop&.title,
            created_at: message.created_at
          }
        }
      end
      
      def ticket_payload(ticket)
        {
          event: 'ticket.created',
          website: website.subdomain,
          timestamp: Time.current.iso8601,
          data: {
            id: ticket.id,
            ticket_number: ticket.ticket_number,
            subject: ticket.subject,
            description: ticket.description,
            status: ticket.status,
            priority: ticket.priority,
            creator_email: ticket.creator.email,
            created_at: ticket.created_at
          }
        }
      end
    end
  end
end
```

### Admin UI

#### Admin Integration Index Page

**File:** `app/views/tenant_admin/integrations/index.html.erb`

```erb
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  <div class="sm:flex sm:items-center sm:justify-between">
    <div>
      <h1 class="text-2xl font-semibold text-gray-900">Integrations</h1>
      <p class="mt-2 text-sm text-gray-700">
        Connect your website to external CRM and support platforms
      </p>
    </div>
  </div>

  <div class="mt-8 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
    <!-- Zoho CRM Card -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <%= image_tag "integrations/zoho-logo.png", class: "h-12 w-12" %>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-gray-900">Zoho CRM</h3>
            <p class="text-sm text-gray-500">
              <%= zoho_integration&.active? ? "Connected" : "Not connected" %>
            </p>
          </div>
        </div>
        
        <div class="mt-4">
          <p class="text-sm text-gray-600">
            Sync contacts, leads, and support cases to Zoho CRM
          </p>
        </div>
        
        <div class="mt-6">
          <% if zoho_integration&.active? %>
            <div class="flex gap-2">
              <%= button_to "Disconnect", 
                  tenant_admin_integration_path(zoho_integration), 
                  method: :delete,
                  data: { confirm: "Are you sure?" },
                  class: "btn btn-outline-danger" %>
              <%= link_to "Settings", 
                  edit_tenant_admin_integration_path(zoho_integration),
                  class: "btn btn-outline-primary" %>
            </div>
            
            <% if zoho_integration.last_synced_at %>
              <p class="mt-2 text-xs text-gray-500">
                Last synced: <%= time_ago_in_words(zoho_integration.last_synced_at) %> ago
              </p>
            <% end %>
            
            <% if zoho_integration.last_error %>
              <div class="mt-2 text-sm text-red-600">
                Error: <%= zoho_integration.last_error %>
              </div>
            <% end %>
          <% else %>
            <%= link_to "Connect to Zoho", 
                tenant_admin_integrations_zoho_authorize_path,
                class: "btn btn-primary" %>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Zendesk Card -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <%= image_tag "integrations/zendesk-logo.png", class: "h-12 w-12" %>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-gray-900">Zendesk</h3>
            <p class="text-sm text-gray-500">
              <%= zendesk_integration&.active? ? "Connected" : "Not connected" %>
            </p>
          </div>
        </div>
        
        <div class="mt-4">
          <p class="text-sm text-gray-600">
            Create support tickets and sync contacts to Zendesk
          </p>
        </div>
        
        <div class="mt-6">
          <% if zendesk_integration&.active? %>
            <div class="flex gap-2">
              <%= button_to "Disconnect", 
                  tenant_admin_integration_path(zendesk_integration), 
                  method: :delete,
                  data: { confirm: "Are you sure?" },
                  class: "btn btn-outline-danger" %>
              <%= link_to "Settings", 
                  edit_tenant_admin_integration_path(zendesk_integration),
                  class: "btn btn-outline-primary" %>
            </div>
          <% else %>
            <%= link_to "Connect to Zendesk", 
                new_tenant_admin_integration_path(platform: 'zendesk'),
                class: "btn btn-primary" %>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Custom Webhook Card -->
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
          </div>
          <div class="ml-4">
            <h3 class="text-lg font-medium text-gray-900">Custom Webhook</h3>
            <p class="text-sm text-gray-500">
              <%= custom_webhooks.count %> configured
            </p>
          </div>
        </div>
        
        <div class="mt-4">
          <p class="text-sm text-gray-600">
            Send data to any webhook endpoint (Zapier, Make, etc.)
          </p>
        </div>
        
        <div class="mt-6">
          <%= link_to "Add Webhook", 
              new_tenant_admin_integration_path(platform: 'custom'),
              class: "btn btn-primary" %>
        </div>
      </div>
    </div>
  </div>

  <!-- Integration Activity Log -->
  <% if @recent_syncs.any? %>
    <div class="mt-8">
      <h2 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h2>
      <div class="bg-white shadow overflow-hidden sm:rounded-md">
        <ul class="divide-y divide-gray-200">
          <% @recent_syncs.each do |sync| %>
            <li class="px-6 py-4">
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-900">
                    <%= sync.integration.name %>
                  </p>
                  <p class="text-sm text-gray-500">
                    <%= sync.record_type %> synced
                  </p>
                </div>
                <div class="flex items-center gap-4">
                  <span class="text-xs text-gray-500">
                    <%= time_ago_in_words(sync.created_at) %> ago
                  </span>
                  <% if sync.success? %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Success
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                      Failed
                    </span>
                  <% end %>
                </div>
              </div>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
  <% end %>
</div>
```

---

## Technical Specifications

### Database Schema

```sql
-- Integrations table
CREATE TABLE pwb_integrations (
  id BIGSERIAL PRIMARY KEY,
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  platform VARCHAR(50) NOT NULL, -- 'zoho_crm', 'zendesk', 'custom'
  name VARCHAR(255) NOT NULL,
  webhook_url VARCHAR(500),
  config JSONB NOT NULL DEFAULT '{}', -- Encrypted
  active BOOLEAN DEFAULT true,
  last_synced_at TIMESTAMP,
  last_error TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_integrations_website_platform ON pwb_integrations(website_id, platform);
CREATE INDEX idx_integrations_active ON pwb_integrations(active);

-- Sync log table (optional, for debugging)
CREATE TABLE pwb_integration_sync_logs (
  id BIGSERIAL PRIMARY KEY,
  integration_id BIGINT NOT NULL REFERENCES pwb_integrations(id),
  record_type VARCHAR(50) NOT NULL, -- 'contact', 'message', 'support_ticket'
  record_id BIGINT NOT NULL,
  action VARCHAR(20) NOT NULL, -- 'create', 'update', 'delete'
  success BOOLEAN NOT NULL,
  error_message TEXT,
  request_payload JSONB,
  response_payload JSONB,
  created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_sync_logs_integration ON pwb_integration_sync_logs(integration_id);
CREATE INDEX idx_sync_logs_created_at ON pwb_integration_sync_logs(created_at DESC);
```

### Environment Variables

```bash
# Zoho CRM
ZOHO_CLIENT_ID=your_client_id
ZOHO_CLIENT_SECRET=your_client_secret

# Zendesk (optional - can be per-tenant)
ZENDESK_DEFAULT_SUBDOMAIN=your_subdomain
```

### API Endpoints

```ruby
# config/routes.rb

namespace :tenant_admin do
  resources :integrations, only: [:index, :new, :create, :edit, :update, :destroy]
  
  namespace :integrations do
    # Zoho OAuth
    get 'zoho/authorize', to: 'zoho_oauth#authorize', as: :zoho_authorize
    get 'zoho/callback', to: 'zoho_oauth#callback', as: :zoho_callback
    
    # Zendesk setup
    get 'zendesk/new', to: 'zendesk_setup#new'
    post 'zendesk', to: 'zendesk_setup#create'
  end
end

# Webhook receivers
namespace :webhooks do
  post 'zendesk/ticket_update', to: 'zendesk#ticket_update'
  post 'zoho/webhook', to: 'zoho#webhook'
end
```

---

## Security Considerations

### 1. API Credential Storage
- Use Rails encrypted credentials for sensitive data
- Store per-tenant API keys in encrypted JSONB column
- Never log API keys or tokens

### 2. Webhook Signature Verification
- Verify all incoming webhooks with HMAC signatures
- Validate webhook source IPs where possible
- Rate limit webhook endpoints

### 3. OAuth Token Management
- Store refresh tokens securely
- Automatic token refresh before expiry
- Revoke tokens on integration disconnect

### 4. Data Privacy
- Only sync explicitly opted-in data
- Allow users to control what data is synced
- Provide data deletion on integration removal

### 5. Tenant Isolation
- Ensure integrations are scoped to website_id
- Validate tenant ownership in all controllers
- Use Current.website pattern consistently

---

## Testing Strategy

### Unit Tests

```ruby
# spec/services/pwb/integrations/zoho_crm_service_spec.rb
RSpec.describe Pwb::Integrations::ZohoCrmService do
  let(:website) { create(:website) }
  let(:integration) { create(:integration, :zoho_crm, website: website) }
  let(:service) { described_class.new(integration) }
  
  describe '#sync_contact' do
    it 'creates contact in Zoho' do
      contact = create(:contact, website: website)
      
      VCR.use_cassette('zoho_create_contact') do
        service.sync_contact(contact)
      end
      
      expect(contact.reload.details['zoho_id']).to be_present
    end
  end
end
```

### Integration Tests

```ruby
# spec/integration/crm_integration_spec.rb
RSpec.describe 'CRM Integration', type: :integration do
  it 'syncs new contact to all active integrations' do
    website = create(:website)
    create(:integration, :zoho_crm, website: website, active: true)
    create(:integration, :zendesk, website: website, active: true)
    
    expect {
      create(:contact, website: website)
    }.to have_enqueued_job(Pwb::IntegrationSyncJob).twice
  end
end
```

### E2E Tests (Playwright)

```javascript
// tests/e2e/admin/integrations.spec.js
test('admin can connect Zoho CRM', async ({ page }) => {
  await page.goto('/tenant_admin/integrations');
  
  await page.click('text=Connect to Zoho');
  
  // Mock OAuth flow
  await page.fill('input[name=email]', 'admin@example.com');
  await page.fill('input[name=password]', 'password');
  await page.click('button:text("Authorize")');
  
  await expect(page.locator('text=Connected')).toBeVisible();
});
```

---

## Rollout Plan

### Week 1-2: Infrastructure
- [ ] Create `pwb_integrations` migration
- [ ] Build `Integration` model with encryption
- [ ] Create base service class
- [ ] Implement `IntegrationSyncJob`
- [ ] Add `Integrable` concern to models
- [ ] Unit tests for base components

### Week 3-4: Zoho CRM
- [ ] Implement `ZohoCrmService`
- [ ] Build OAuth flow
- [ ] Create admin UI for Zoho setup
- [ ] Add contact sync
- [ ] Add message → lead sync
- [ ] Add support ticket → case sync
- [ ] Integration tests

### Week 5-6: Zendesk
- [ ] Implement `ZendeskService`
- [ ] Build API token setup UI
- [ ] Add contact → user sync
- [ ] Add message → ticket sync
- [ ] Add support ticket sync
- [ ] Implement webhook receiver for two-way sync
- [ ] Integration tests

### Week 7: Custom Webhooks & Documentation
- [ ] Implement `WebhookService`
- [ ] Build custom webhook UI
- [ ] Write Zapier integration guide
- [ ] Create API documentation
- [ ] E2E tests
- [ ] User documentation

### Week 8: Polish & Launch
- [ ] Security audit
- [ ] Performance optimization
- [ ] Error handling improvements
- [ ] Admin dashboard enhancements
- [ ] Beta testing with select customers
- [ ] Production deployment

---

## Future Enhancements

### Phase 2 Features
- HubSpot integration
- Salesforce integration
- Pipedrive integration
- Microsoft Dynamics 365
- Two-way sync for all platforms
- Bulk import from CRM
- Field mapping customization
- Integration analytics dashboard

### Advanced Features
- AI-powered lead scoring
- Automatic contact enrichment
- Smart deduplication
- Integration marketplace
- Webhook retry logic with exponential backoff
- Integration health monitoring
- Rate limit handling
- Batch sync for large datasets

---

## Appendix

### A. Zoho CRM API Reference
- **Documentation:** https://www.zoho.com/crm/developer/docs/api/v3/
- **OAuth:** https://www.zoho.com/accounts/protocol/oauth.html
- **Modules:** Contacts, Leads, Cases, Notes
- **Rate Limits:** 100 API calls per minute

### B. Zendesk API Reference
- **Documentation:** https://developer.zendesk.com/api-reference/
- **Authentication:** API Token or OAuth
- **Endpoints:** Users, Tickets, Organizations
- **Rate Limits:** 700 requests per minute

### C. Webhook Payload Examples

**Contact Created:**
```json
{
  "event": "contact.created",
  "website": "example-agency",
  "timestamp": "2025-01-08T20:30:00Z",
  "data": {
    "id": 123,
    "first_name": "John",
    "last_name": "Doe",
    "email": "john@example.com",
    "phone": "+1234567890"
  }
}
```

**Message Created:**
```json
{
  "event": "message.created",
  "website": "example-agency",
  "timestamp": "2025-01-08T20:30:00Z",
  "data": {
    "id": 456,
    "contact_email": "john@example.com",
    "message": "Interested in property ABC123",
    "property_reference": "ABC123",
    "property_title": "Luxury Villa"
  }
}
```

---

## Questions & Support

For implementation questions:
- Review existing Twilio integration: `docs/integrations/TWILIO_INTEGRATION_PLAN.md`
- Check external feeds pattern: `app/services/pwb/external_feed/`
- Consult multi-tenancy docs: `docs/multi_tenancy/README.md`

---

**End of Document**
