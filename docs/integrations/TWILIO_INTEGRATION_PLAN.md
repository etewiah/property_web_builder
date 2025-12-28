# Twilio Integration Plan for PropertyWebBuilder

This document outlines a comprehensive plan for integrating Twilio telephony features into PropertyWebBuilder.

## Executive Summary

Twilio integration will add phone/SMS capabilities to PropertyWebBuilder, enabling:
- **Click-to-Call**: Website visitors can request instant callbacks
- **SMS Lead Capture**: Text a code to get property info
- **Call Tracking**: Track which listings generate phone inquiries
- **SMS Notifications**: Instant alerts to agents about new leads

## Architecture Overview

### Design Principles

Following the existing patterns in PropertyWebBuilder (similar to `NtfyService`):

1. **Per-tenant configuration** - Each website has its own Twilio settings
2. **Service-oriented** - Dedicated `TwilioService` class
3. **Background jobs** - Async operations via Solid Queue
4. **Webhook-ready** - Handle Twilio callbacks securely
5. **Graceful degradation** - Features disabled cleanly when not configured

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PropertyWebBuilder                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │   Website    │───▶│TwilioConfig  │───▶│    TwilioService     │  │
│  │   (tenant)   │    │  (settings)  │    │                      │  │
│  └──────────────┘    └──────────────┘    │  - send_sms()        │  │
│         │                                 │  - initiate_call()   │  │
│         │                                 │  - handle_webhook()  │  │
│         ▼                                 └──────────┬───────────┘  │
│  ┌──────────────┐                                    │              │
│  │   Contact    │◀───────────────────────────────────┘              │
│  │   Message    │                                                   │
│  │  PhoneCall   │◀──────────┐                                       │
│  └──────────────┘           │                                       │
│                              │                                       │
│  ┌──────────────────────────┴───────────────────────────────────┐  │
│  │                    Webhook Controller                         │  │
│  │                  POST /webhooks/twilio                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                         ┌──────────────────┐
                         │   Twilio API     │
                         │  - Voice         │
                         │  - SMS           │
                         │  - Phone Numbers │
                         └──────────────────┘
```

## Database Schema

### Migration: Add Twilio fields to pwb_websites

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_twilio_settings_to_websites.rb
class AddTwilioSettingsToWebsites < ActiveRecord::Migration[7.1]
  def change
    add_column :pwb_websites, :twilio_enabled, :boolean, default: false, null: false
    add_column :pwb_websites, :twilio_account_sid, :string
    add_column :pwb_websites, :twilio_auth_token, :string  # Encrypted
    add_column :pwb_websites, :twilio_phone_number, :string

    # Feature toggles
    add_column :pwb_websites, :twilio_click_to_call_enabled, :boolean, default: true, null: false
    add_column :pwb_websites, :twilio_sms_notifications_enabled, :boolean, default: true, null: false
    add_column :pwb_websites, :twilio_sms_lead_capture_enabled, :boolean, default: false, null: false

    # Notification preferences
    add_column :pwb_websites, :twilio_notify_on_inquiry, :boolean, default: true, null: false

    add_index :pwb_websites, :twilio_enabled
  end
end
```

### New Model: PhoneCall (for call tracking)

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_pwb_phone_calls.rb
class CreatePwbPhoneCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_phone_calls do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :contact, foreign_key: { to_table: :pwb_contacts }
      t.references :prop, foreign_key: { to_table: :pwb_props }

      # Call details
      t.string :twilio_call_sid, null: false
      t.string :direction, null: false  # inbound, outbound, click_to_call
      t.string :status  # queued, ringing, in-progress, completed, failed, busy, no-answer
      t.string :from_number
      t.string :to_number
      t.integer :duration_seconds
      t.string :recording_url
      t.string :recording_sid

      # Tracking
      t.string :source_page  # URL where click-to-call was triggered
      t.string :utm_source
      t.string :utm_campaign

      t.datetime :started_at
      t.datetime :answered_at
      t.datetime :ended_at

      t.timestamps
    end

    add_index :pwb_phone_calls, :twilio_call_sid, unique: true
    add_index :pwb_phone_calls, :status
    add_index :pwb_phone_calls, :direction
    add_index :pwb_phone_calls, [:website_id, :created_at]
  end
end
```

### New Model: SmsMessage (for SMS tracking)

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_pwb_sms_messages.rb
class CreatePwbSmsMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_sms_messages do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :contact, foreign_key: { to_table: :pwb_contacts }
      t.references :prop, foreign_key: { to_table: :pwb_props }

      # Message details
      t.string :twilio_message_sid
      t.string :direction, null: false  # inbound, outbound
      t.string :status  # queued, sent, delivered, failed, undelivered
      t.string :from_number
      t.string :to_number
      t.text :body
      t.string :error_code
      t.string :error_message

      # For lead capture codes
      t.string :property_code  # e.g., "HOUSE123"

      t.timestamps
    end

    add_index :pwb_sms_messages, :twilio_message_sid
    add_index :pwb_sms_messages, :status
    add_index :pwb_sms_messages, :direction
    add_index :pwb_sms_messages, [:website_id, :created_at]
  end
end
```

## Models

### Pwb::PhoneCall

```ruby
# app/models/pwb/phone_call.rb
module Pwb
  class PhoneCall < ApplicationRecord
    self.table_name = 'pwb_phone_calls'

    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :contact, class_name: 'Pwb::Contact', optional: true
    belongs_to :prop, class_name: 'Pwb::Prop', optional: true

    # Directions
    DIRECTIONS = %w[inbound outbound click_to_call].freeze

    # Twilio call statuses
    STATUSES = %w[queued ringing in-progress completed failed busy no-answer canceled].freeze

    validates :twilio_call_sid, presence: true, uniqueness: true
    validates :direction, presence: true, inclusion: { in: DIRECTIONS }
    validates :status, inclusion: { in: STATUSES }, allow_nil: true

    scope :completed, -> { where(status: 'completed') }
    scope :click_to_call, -> { where(direction: 'click_to_call') }
    scope :recent, -> { order(created_at: :desc) }

    def completed?
      status == 'completed'
    end

    def duration_formatted
      return nil unless duration_seconds

      minutes = duration_seconds / 60
      seconds = duration_seconds % 60
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end
end
```

### Pwb::SmsMessage

```ruby
# app/models/pwb/sms_message.rb
module Pwb
  class SmsMessage < ApplicationRecord
    self.table_name = 'pwb_sms_messages'

    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :contact, class_name: 'Pwb::Contact', optional: true
    belongs_to :prop, class_name: 'Pwb::Prop', optional: true

    DIRECTIONS = %w[inbound outbound].freeze
    STATUSES = %w[queued sent delivered failed undelivered].freeze

    validates :direction, presence: true, inclusion: { in: DIRECTIONS }
    validates :body, presence: true, length: { maximum: 1600 }

    scope :inbound, -> { where(direction: 'inbound') }
    scope :outbound, -> { where(direction: 'outbound') }
    scope :delivered, -> { where(status: 'delivered') }
    scope :recent, -> { order(created_at: :desc) }
  end
end
```

### Website concern for Twilio

```ruby
# app/models/concerns/pwb/website_twilio_configurable.rb
module Pwb
  module WebsiteTwilioConfigurable
    extend ActiveSupport::Concern

    included do
      has_many :phone_calls, class_name: 'Pwb::PhoneCall', dependent: :destroy
      has_many :sms_messages, class_name: 'Pwb::SmsMessage', dependent: :destroy

      # Encrypt the auth token
      encrypts :twilio_auth_token
    end

    def twilio_configured?
      twilio_enabled? &&
        twilio_account_sid.present? &&
        twilio_auth_token.present? &&
        twilio_phone_number.present?
    end

    def twilio_client
      return nil unless twilio_configured?

      @twilio_client ||= Twilio::REST::Client.new(
        twilio_account_sid,
        twilio_auth_token
      )
    end
  end
end
```

## Service Layer

### TwilioService

```ruby
# app/services/twilio_service.rb
class TwilioService
  class ConfigurationError < StandardError; end
  class ApiError < StandardError; end

  class << self
    # ==================
    # Click-to-Call
    # ==================

    # Initiate a click-to-call: calls visitor, then connects to agent
    #
    # @param website [Pwb::Website] The website
    # @param visitor_phone [String] Visitor's phone number
    # @param agent_phone [String] Agent's phone number (optional, uses website default)
    # @param property [Pwb::Prop] Associated property (optional)
    # @param source_url [String] Page URL where click was triggered
    # @return [Pwb::PhoneCall] The created phone call record
    def click_to_call(website:, visitor_phone:, agent_phone: nil, property: nil, source_url: nil)
      validate_configuration!(website, :click_to_call)

      agent_phone ||= website.email_for_property_contact_form # Could add dedicated phone field

      # Create call record first
      phone_call = website.phone_calls.create!(
        direction: 'click_to_call',
        status: 'queued',
        from_number: website.twilio_phone_number,
        to_number: visitor_phone,
        prop: property,
        source_page: source_url,
        twilio_call_sid: "pending_#{SecureRandom.hex(8)}"
      )

      begin
        # Initiate call via Twilio
        call = website.twilio_client.calls.create(
          to: visitor_phone,
          from: website.twilio_phone_number,
          url: twilio_callback_url(website, phone_call, agent_phone),
          status_callback: twilio_status_callback_url(website),
          status_callback_event: ['initiated', 'ringing', 'answered', 'completed']
        )

        # Update with real SID
        phone_call.update!(
          twilio_call_sid: call.sid,
          status: call.status
        )

        phone_call
      rescue Twilio::REST::RestError => e
        phone_call.update!(status: 'failed')
        raise ApiError, "Twilio API error: #{e.message}"
      end
    end

    # ==================
    # SMS
    # ==================

    # Send an SMS notification
    #
    # @param website [Pwb::Website] The website
    # @param to [String] Recipient phone number
    # @param body [String] Message body
    # @param contact [Pwb::Contact] Associated contact (optional)
    # @return [Pwb::SmsMessage] The created SMS record
    def send_sms(website:, to:, body:, contact: nil, property: nil)
      validate_configuration!(website, :sms)

      sms_message = website.sms_messages.create!(
        direction: 'outbound',
        status: 'queued',
        from_number: website.twilio_phone_number,
        to_number: to,
        body: body,
        contact: contact,
        prop: property
      )

      begin
        message = website.twilio_client.messages.create(
          to: to,
          from: website.twilio_phone_number,
          body: body,
          status_callback: twilio_sms_status_callback_url(website)
        )

        sms_message.update!(
          twilio_message_sid: message.sid,
          status: message.status
        )

        sms_message
      rescue Twilio::REST::RestError => e
        sms_message.update!(
          status: 'failed',
          error_message: e.message
        )
        raise ApiError, "Twilio SMS error: #{e.message}"
      end
    end

    # Send SMS notification to agent about new inquiry
    #
    # @param website [Pwb::Website] The website
    # @param message [Pwb::Message] The inquiry message
    def notify_inquiry_via_sms(website, message)
      return unless website.twilio_configured?
      return unless website.twilio_sms_notifications_enabled?
      return unless website.twilio_notify_on_inquiry?

      # Get agent phone (would need to add this field to website or agency)
      agent_phone = website.agency&.phone_number
      return if agent_phone.blank?

      body = build_inquiry_notification(message)

      TwilioSmsJob.perform_later(
        website_id: website.id,
        to: agent_phone,
        body: body,
        contact_id: message.contact_id
      )
    end

    # ==================
    # Lead Capture (Text for Info)
    # ==================

    # Process an inbound SMS for property info
    #
    # @param website [Pwb::Website] The website
    # @param from [String] Sender's phone number
    # @param body [String] Message body (should contain property code)
    def process_inbound_sms(website:, from:, body:)
      return unless website.twilio_sms_lead_capture_enabled?

      # Record inbound message
      sms_message = website.sms_messages.create!(
        direction: 'inbound',
        status: 'delivered',
        from_number: from,
        to_number: website.twilio_phone_number,
        body: body
      )

      # Extract property code (e.g., "INFO HOUSE123" or just "HOUSE123")
      property_code = extract_property_code(body)

      if property_code
        property = find_property_by_code(website, property_code)

        if property
          sms_message.update!(prop: property, property_code: property_code)
          send_property_info(website, from, property)
          create_lead_from_sms(website, from, property, sms_message)
        else
          send_sms(
            website: website,
            to: from,
            body: "Sorry, we couldn't find a property with code '#{property_code}'. Please check the code and try again."
          )
        end
      else
        # No code found, send help message
        send_sms(
          website: website,
          to: from,
          body: "Thanks for your interest! Text a property code (e.g., 'HOUSE123') to get instant property details."
        )
      end
    end

    # ==================
    # Webhooks
    # ==================

    # Handle Twilio voice webhook (generates TwiML)
    def handle_voice_webhook(params)
      call_sid = params['CallSid']
      phone_call = Pwb::PhoneCall.find_by(twilio_call_sid: call_sid)

      return busy_twiml unless phone_call

      # Generate TwiML to connect to agent
      agent_phone = params['agent_phone']

      Twilio::TwiML::VoiceResponse.new do |response|
        response.say(message: "Connecting you now. Please hold.")
        response.dial(caller_id: phone_call.from_number) do |dial|
          dial.number(agent_phone)
        end
      end.to_s
    end

    # Handle call status updates
    def handle_call_status(params)
      call_sid = params['CallSid']
      phone_call = Pwb::PhoneCall.find_by(twilio_call_sid: call_sid)

      return unless phone_call

      phone_call.update!(
        status: params['CallStatus'],
        duration_seconds: params['CallDuration']&.to_i,
        answered_at: params['CallStatus'] == 'in-progress' ? Time.current : phone_call.answered_at,
        ended_at: params['CallStatus'] == 'completed' ? Time.current : phone_call.ended_at
      )
    end

    # Handle SMS status updates
    def handle_sms_status(params)
      message_sid = params['MessageSid']
      sms_message = Pwb::SmsMessage.find_by(twilio_message_sid: message_sid)

      return unless sms_message

      sms_message.update!(
        status: params['MessageStatus'],
        error_code: params['ErrorCode'],
        error_message: params['ErrorMessage']
      )
    end

    private

    def validate_configuration!(website, feature)
      unless website&.twilio_configured?
        raise ConfigurationError, "Twilio is not configured for this website"
      end

      case feature
      when :click_to_call
        unless website.twilio_click_to_call_enabled?
          raise ConfigurationError, "Click-to-call is not enabled"
        end
      when :sms
        unless website.twilio_sms_notifications_enabled? || website.twilio_sms_lead_capture_enabled?
          raise ConfigurationError, "SMS features are not enabled"
        end
      end
    end

    def twilio_callback_url(website, phone_call, agent_phone)
      Rails.application.routes.url_helpers.twilio_voice_webhook_url(
        host: website_host(website),
        call_id: phone_call.id,
        agent_phone: agent_phone
      )
    end

    def twilio_status_callback_url(website)
      Rails.application.routes.url_helpers.twilio_call_status_webhook_url(
        host: website_host(website)
      )
    end

    def twilio_sms_status_callback_url(website)
      Rails.application.routes.url_helpers.twilio_sms_status_webhook_url(
        host: website_host(website)
      )
    end

    def website_host(website)
      website.custom_domain_active? ? website.custom_domain : "#{website.subdomain}.#{ENV.fetch('PLATFORM_DOMAIN', 'propertywebbuilder.com')}"
    end

    def build_inquiry_notification(message)
      parts = ["New inquiry!"]
      parts << "From: #{message.contact&.first_name || 'Unknown'}"
      parts << "Email: #{message.contact&.primary_email}" if message.contact&.primary_email.present?
      parts << message.content.to_s.truncate(100) if message.content.present?
      parts.join("\n")
    end

    def extract_property_code(body)
      # Match patterns like "INFO ABC123", "ABC123", "REF: ABC123"
      match = body.strip.upcase.match(/(?:INFO|REF:?\s*)?([A-Z0-9]{4,20})/i)
      match&.[](1)
    end

    def find_property_by_code(website, code)
      website.props.find_by(reference: code) ||
        website.props.find_by("UPPER(reference) = ?", code.upcase)
    end

    def send_property_info(website, to, property)
      body = build_property_info_sms(property, website)
      send_sms(website: website, to: to, body: body, property: property)
    end

    def build_property_info_sms(property, website)
      parts = [property.title.to_s.truncate(50)]

      if property.for_sale? && property.sale_price.present?
        parts << "Price: #{property.formatted_sale_price}"
      elsif property.for_rent? && property.rental_price.present?
        parts << "Rent: #{property.formatted_rental_price}/month"
      end

      parts << "#{property.bedrooms}BR #{property.bathrooms}BA" if property.bedrooms.present?
      parts << property.city if property.city.present?

      # Add link
      property_url = "https://#{website_host(website)}/properties/#{property.id}"
      parts << "Details: #{property_url}"

      parts.join(" | ")
    end

    def create_lead_from_sms(website, phone_number, property, sms_message)
      # Find or create contact
      contact = website.contacts.find_or_create_by(primary_phone_number: phone_number)

      # Create inquiry message
      message = website.messages.create!(
        contact: contact,
        title: "SMS Lead: #{property.reference}",
        content: "Texted for info on #{property.title}",
        origin_ip: 'sms',
        url: "SMS Lead Capture"
      )

      sms_message.update!(contact: contact)

      # Trigger normal inquiry workflow (email, notifications)
      Pwb::EnquiryMailer.property_enquiry_targeting_agency(contact, message, property).deliver_later
      NtfyService.notify_inquiry(website, message)
    end

    def busy_twiml
      Twilio::TwiML::VoiceResponse.new do |response|
        response.say(message: "Sorry, we're unable to connect your call. Please try again later.")
        response.hangup
      end.to_s
    end
  end
end
```

## Controllers

### Webhook Controller

```ruby
# app/controllers/webhooks/twilio_controller.rb
module Webhooks
  class TwilioController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_twilio_signature

    # POST /webhooks/twilio/voice
    # Generates TwiML for call handling
    def voice
      twiml = TwilioService.handle_voice_webhook(params)
      render xml: twiml, content_type: 'text/xml'
    end

    # POST /webhooks/twilio/call_status
    # Receives call status updates
    def call_status
      TwilioService.handle_call_status(params)
      head :ok
    end

    # POST /webhooks/twilio/sms
    # Receives inbound SMS messages
    def sms
      website = find_website_by_phone(params['To'])

      if website
        TwilioService.process_inbound_sms(
          website: website,
          from: params['From'],
          body: params['Body']
        )
      end

      head :ok
    end

    # POST /webhooks/twilio/sms_status
    # Receives SMS delivery status updates
    def sms_status
      TwilioService.handle_sms_status(params)
      head :ok
    end

    private

    def verify_twilio_signature
      validator = Twilio::Security::RequestValidator.new(
        find_auth_token_for_request
      )

      unless validator.validate(
        request.original_url,
        params.to_unsafe_h,
        request.headers['X-Twilio-Signature']
      )
        head :forbidden
      end
    end

    def find_website_by_phone(phone_number)
      Pwb::Website.find_by(twilio_phone_number: phone_number)
    end

    def find_auth_token_for_request
      # Find website from phone number or call/message SID
      website = if params['To'].present?
        find_website_by_phone(params['To'])
      elsif params['CallSid'].present?
        Pwb::PhoneCall.find_by(twilio_call_sid: params['CallSid'])&.website
      elsif params['MessageSid'].present?
        Pwb::SmsMessage.find_by(twilio_message_sid: params['MessageSid'])&.website
      end

      website&.twilio_auth_token || ENV['TWILIO_AUTH_TOKEN']
    end
  end
end
```

### Click-to-Call API Controller

```ruby
# app/controllers/api/v1/click_to_call_controller.rb
module Api
  module V1
    class ClickToCallController < ApiController
      before_action :set_website

      # POST /api/v1/click_to_call
      # Initiates a click-to-call request
      def create
        unless @website.twilio_configured? && @website.twilio_click_to_call_enabled?
          return render json: { error: 'Click-to-call is not available' }, status: :service_unavailable
        end

        phone_call = TwilioService.click_to_call(
          website: @website,
          visitor_phone: params[:phone],
          property: params[:property_id] ? @website.props.find_by(id: params[:property_id]) : nil,
          source_url: params[:source_url]
        )

        render json: {
          success: true,
          message: "We're calling you now!",
          call_id: phone_call.id
        }
      rescue TwilioService::ConfigurationError => e
        render json: { error: e.message }, status: :service_unavailable
      rescue TwilioService::ApiError => e
        render json: { error: 'Unable to connect your call. Please try again.' }, status: :unprocessable_entity
      end

      private

      def set_website
        @website = Pwb::Current.website
      end
    end
  end
end
```

## Background Jobs

```ruby
# app/jobs/twilio_sms_job.rb
class TwilioSmsJob < ApplicationJob
  queue_as :default

  retry_on TwilioService::ApiError, wait: :polynomially_longer, attempts: 3

  def perform(website_id:, to:, body:, contact_id: nil, property_id: nil)
    website = Pwb::Website.find(website_id)
    contact = contact_id ? Pwb::Contact.find(contact_id) : nil
    property = property_id ? Pwb::Prop.find(property_id) : nil

    TwilioService.send_sms(
      website: website,
      to: to,
      body: body,
      contact: contact,
      property: property
    )
  end
end
```

## Frontend Components

### Click-to-Call Widget (Stimulus Controller)

```javascript
// app/javascript/controllers/click_to_call_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["phoneInput", "submitButton", "message", "form"]
  static values = {
    propertyId: String,
    endpoint: { type: String, default: "/api/v1/click_to_call" }
  }

  connect() {
    // Format phone as user types
    if (this.hasPhoneInputTarget) {
      this.phoneInputTarget.addEventListener("input", this.formatPhone.bind(this))
    }
  }

  formatPhone(event) {
    let value = event.target.value.replace(/\D/g, "")
    if (value.length > 10) value = value.slice(0, 10)

    if (value.length >= 6) {
      value = `(${value.slice(0,3)}) ${value.slice(3,6)}-${value.slice(6)}`
    } else if (value.length >= 3) {
      value = `(${value.slice(0,3)}) ${value.slice(3)}`
    }

    event.target.value = value
  }

  async submit(event) {
    event.preventDefault()

    const phone = this.phoneInputTarget.value.replace(/\D/g, "")

    if (phone.length < 10) {
      this.showMessage("Please enter a valid phone number", "error")
      return
    }

    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Calling..."

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          phone: `+1${phone}`,
          property_id: this.propertyIdValue,
          source_url: window.location.href
        })
      })

      const data = await response.json()

      if (response.ok) {
        this.showMessage(data.message, "success")
        this.formTarget.reset()
      } else {
        this.showMessage(data.error || "Something went wrong", "error")
      }
    } catch (error) {
      this.showMessage("Unable to connect. Please try again.", "error")
    } finally {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Call Me Now"
    }
  }

  showMessage(text, type) {
    this.messageTarget.textContent = text
    this.messageTarget.className = type === "success"
      ? "text-green-600 text-sm mt-2"
      : "text-red-600 text-sm mt-2"
  }
}
```

### Click-to-Call Widget View

```erb
<!-- app/views/shared/_click_to_call_widget.html.erb -->
<% if current_website&.twilio_click_to_call_enabled? %>
  <div class="click-to-call-widget bg-white rounded-lg shadow-md p-4"
       data-controller="click-to-call"
       data-click-to-call-property-id-value="<%= property&.id %>">

    <h3 class="text-lg font-semibold text-gray-900 mb-2">
      Want us to call you?
    </h3>
    <p class="text-sm text-gray-600 mb-4">
      Enter your phone number and we'll connect you with an agent instantly.
    </p>

    <form data-click-to-call-target="form" data-action="submit->click-to-call#submit">
      <div class="flex space-x-2">
        <input type="tel"
               data-click-to-call-target="phoneInput"
               placeholder="(555) 123-4567"
               class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
               required>

        <button type="submit"
                data-click-to-call-target="submitButton"
                class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:ring-offset-2 whitespace-nowrap">
          Call Me Now
        </button>
      </div>

      <div data-click-to-call-target="message" class="mt-2"></div>
    </form>

    <p class="text-xs text-gray-500 mt-2">
      By requesting a call, you agree to receive a phone call from our team.
    </p>
  </div>
<% end %>
```

## Admin Settings UI

```erb
<!-- app/views/site_admin/website/settings/_telephony_tab.html.erb -->
<div class="p-6">
  <div class="mb-6">
    <h2 class="text-xl font-semibold text-gray-900">Telephony Settings</h2>
    <p class="mt-1 text-sm text-gray-500">
      Configure Twilio integration for click-to-call, SMS notifications, and lead capture.
    </p>
  </div>

  <%= form_with model: @website, url: site_admin_website_settings_path, method: :patch, local: true, class: "space-y-6" do |f| %>
    <input type="hidden" name="tab" value="telephony">

    <!-- Enable/Disable Toggle -->
    <div class="p-4 bg-gray-50 rounded-lg border border-gray-200">
      <div class="flex items-start">
        <div class="flex items-center h-5">
          <%= f.check_box :twilio_enabled,
              class: "h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500",
              id: "twilio_enabled" %>
        </div>
        <div class="ml-3">
          <label for="twilio_enabled" class="text-sm font-medium text-gray-700">
            Enable Twilio Integration
          </label>
          <p class="text-sm text-gray-500 mt-1">
            Enable phone calls and SMS features powered by Twilio.
          </p>
        </div>
      </div>
    </div>

    <!-- Twilio Credentials -->
    <div id="twilio-config" class="space-y-4 <%= 'opacity-50' unless @website.twilio_enabled? %>">
      <h3 class="text-lg font-medium text-gray-900 border-b border-gray-200 pb-2">
        Twilio Credentials
      </h3>
      <p class="text-sm text-gray-500">
        Get your credentials from the
        <a href="https://console.twilio.com" target="_blank" class="text-blue-600 hover:underline">Twilio Console</a>.
      </p>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label for="twilio_account_sid" class="block text-sm font-medium text-gray-700 mb-1">
            Account SID
          </label>
          <%= f.text_field :twilio_account_sid,
              class: "w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500",
              placeholder: "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" %>
        </div>

        <div>
          <label for="twilio_auth_token" class="block text-sm font-medium text-gray-700 mb-1">
            Auth Token
          </label>
          <%= f.password_field :twilio_auth_token,
              class: "w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500",
              placeholder: "••••••••••••••••",
              value: @website.twilio_auth_token.present? ? '••••••••••••' : '' %>
        </div>
      </div>

      <div>
        <label for="twilio_phone_number" class="block text-sm font-medium text-gray-700 mb-1">
          Twilio Phone Number
        </label>
        <%= f.text_field :twilio_phone_number,
            class: "w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500",
            placeholder: "+15551234567" %>
        <p class="mt-1 text-sm text-gray-500">
          Your Twilio phone number in E.164 format (e.g., +15551234567).
        </p>
      </div>
    </div>

    <!-- Feature Toggles -->
    <div id="twilio-features" class="space-y-4 <%= 'opacity-50' unless @website.twilio_enabled? %>">
      <h3 class="text-lg font-medium text-gray-900 border-b border-gray-200 pb-2">Features</h3>

      <div class="space-y-3">
        <!-- Click-to-Call -->
        <div class="flex items-start p-3 bg-white border border-gray-200 rounded-lg">
          <div class="flex items-center h-5">
            <%= f.check_box :twilio_click_to_call_enabled,
                class: "h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500" %>
          </div>
          <div class="ml-3">
            <label class="text-sm font-medium text-gray-700">Click-to-Call Widget</label>
            <p class="text-sm text-gray-500">
              Allow visitors to request an instant callback from your website.
            </p>
          </div>
        </div>

        <!-- SMS Notifications -->
        <div class="flex items-start p-3 bg-white border border-gray-200 rounded-lg">
          <div class="flex items-center h-5">
            <%= f.check_box :twilio_sms_notifications_enabled,
                class: "h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500" %>
          </div>
          <div class="ml-3">
            <label class="text-sm font-medium text-gray-700">SMS Notifications</label>
            <p class="text-sm text-gray-500">
              Receive SMS alerts when new inquiries come in.
            </p>
          </div>
        </div>

        <!-- SMS Lead Capture -->
        <div class="flex items-start p-3 bg-white border border-gray-200 rounded-lg">
          <div class="flex items-center h-5">
            <%= f.check_box :twilio_sms_lead_capture_enabled,
                class: "h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500" %>
          </div>
          <div class="ml-3">
            <label class="text-sm font-medium text-gray-700">SMS Lead Capture</label>
            <p class="text-sm text-gray-500">
              Let visitors text a property code to receive instant property details.
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Submit -->
    <div class="pt-4 border-t border-gray-200">
      <%= f.submit "Save Telephony Settings",
          class: "px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 cursor-pointer" %>
    </div>
  <% end %>
</div>
```

## Routes

```ruby
# config/routes.rb (additions)

# API endpoints
namespace :api do
  namespace :v1 do
    resources :click_to_call, only: [:create]
  end
end

# Twilio webhooks (must be publicly accessible)
namespace :webhooks do
  namespace :twilio do
    post 'voice', to: 'twilio#voice'
    post 'call_status', to: 'twilio#call_status'
    post 'sms', to: 'twilio#sms'
    post 'sms_status', to: 'twilio#sms_status'
  end
end
```

## Gemfile Addition

```ruby
# Gemfile
gem 'twilio-ruby', '~> 6.0'
```

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Add `twilio-ruby` gem
- [ ] Create migrations for website settings and phone_calls table
- [ ] Add `WebsiteTwilioConfigurable` concern
- [ ] Create `Pwb::PhoneCall` model
- [ ] Create basic `TwilioService` with click-to-call
- [ ] Add admin settings UI (telephony tab)

### Phase 2: Click-to-Call (Week 2)
- [ ] Create webhook controller with signature verification
- [ ] Create API controller for click-to-call requests
- [ ] Build Stimulus controller for frontend widget
- [ ] Create click-to-call widget partial
- [ ] Add routes
- [ ] Test end-to-end click-to-call flow

### Phase 3: SMS Features (Week 3)
- [ ] Create `Pwb::SmsMessage` model and migration
- [ ] Implement SMS sending in TwilioService
- [ ] Add SMS notification on new inquiry
- [ ] Implement inbound SMS handling (lead capture)
- [ ] Create `TwilioSmsJob` for async sending
- [ ] Test SMS flows

### Phase 4: Admin & Reporting (Week 4)
- [ ] Add call log view in admin
- [ ] Add SMS log view in admin
- [ ] Create basic analytics (calls per property, conversion tracking)
- [ ] Add call recording support (optional)
- [ ] Documentation and testing

## Cost Considerations

| Feature | Twilio Cost (approx.) |
|---------|----------------------|
| Phone Number | $1-2/month |
| Outbound Call | $0.013/min |
| Inbound Call | $0.0085/min |
| Outbound SMS | $0.0079/message |
| Inbound SMS | $0.0079/message |

For a typical real estate website with 50 inquiries/month:
- ~$2/month for phone number
- ~$5-10/month for SMS notifications
- ~$10-20/month if using click-to-call

**Total: ~$15-35/month** for most agencies

## Security Considerations

1. **Credential Storage**: Auth tokens are encrypted using Rails' built-in encryption
2. **Webhook Verification**: All Twilio webhooks verify the `X-Twilio-Signature` header
3. **Rate Limiting**: Consider adding rate limiting to click-to-call endpoint
4. **Phone Validation**: Validate phone numbers before initiating calls
5. **Tenant Isolation**: All records are scoped to website_id

## Testing Strategy

```ruby
# spec/services/twilio_service_spec.rb
RSpec.describe TwilioService do
  let(:website) { create(:pwb_website, :with_twilio) }

  describe '.click_to_call' do
    it 'creates a phone call record' do
      expect {
        TwilioService.click_to_call(
          website: website,
          visitor_phone: '+15551234567'
        )
      }.to change(Pwb::PhoneCall, :count).by(1)
    end

    it 'initiates call via Twilio API' do
      # Mock Twilio client
    end
  end
end
```

## Conclusion

This integration plan provides a complete blueprint for adding Twilio telephony features to PropertyWebBuilder. The design follows existing patterns in the codebase (similar to NtfyService) and provides:

1. **Click-to-Call** - Instant visitor-to-agent connection
2. **SMS Notifications** - Real-time alerts for agents
3. **SMS Lead Capture** - Text-for-info functionality
4. **Call/SMS Tracking** - Full audit trail and analytics

The phased implementation allows for incremental delivery and testing, with the most valuable feature (click-to-call) delivered first.
