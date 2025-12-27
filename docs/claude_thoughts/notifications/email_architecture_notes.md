# Email Architecture Analysis & Design Patterns

## Current Architecture

### Synchronous Email Delivery Pattern

```
HTTP Request
    ↓
ContactUsController
    ├─ Validate input
    ├─ Create Contact record
    ├─ Create Message record
    ├─ Save to database
    ↓
EnquiryMailer.method(contact, message).deliver_now
    ├─ Render template
    ├─ Connect to SMTP
    ├─ Send email (BLOCKING)
    ↓
HTTP Response 200 OK
    ↓
NtfyNotificationJob.perform_later (optional, async)
```

### Observations

1. **Email Delivery is Blocking**: The HTTP request waits for email to send
   - On SMTP timeout: Request hangs
   - On SMTP failure: Exception may not be caught
   - On slow SMTP: User experiences lag

2. **Partial Async Adoption**: 
   - Contact form uses synchronous email
   - But already has async push notifications via NtfyJob
   - Inconsistent pattern

3. **No Delivery State Management**:
   - Message record has `delivery_success` field (never updated)
   - No way to know which emails actually sent
   - No retry mechanism

---

## Data Model Insights

### Contact Model Design

**Good:**
- Reusable contact storage across multiple messages
- Rich profile information (addresses, social links)
- Can link to User (for registered visitors)

**Issues:**
- Email indexed but not unique (should allow duplicates for different names?)
- No consent/opt-out tracking
- No bounced email flag
- `flags` field (integer) not documented - unclear usage

### Message Model Design

**Good:**
- Captures request metadata (IP, user-agent, locale)
- Has delivery_email field (allows changing recipient after form submit)
- Associates contact with message

**Issues:**
- `delivery_success` field unused
- No `delivery_error` field (can't see why email failed)
- No `delivery_timestamp` (can't track when sent)
- No `retry_count` (no retry logic anyway)
- Boolean success flag insufficient (should track states: pending, sent, failed, bounced)

**Suggested Enhancement:**
```ruby
# Better delivery tracking
t.integer :delivery_status, default: 0  # enum: pending, sent, failed, bounced
t.text :delivery_error, null: true      # error message
t.integer :retry_count, default: 0      # for retry logic
t.datetime :delivery_timestamp           # when sent
t.datetime :bounced_at, null: true       # if bounce detected
```

---

## Mailer Architecture

### ApplicationMailer Pattern

**Current:**
```ruby
class ApplicationMailer < ActionMailer::Base
  # default from: 'service@propertywebbuilder.com'  # COMMENTED OUT
  layout "mailer"
end
```

**Issues:**
- No default from address
- No error handling
- No before/after callbacks
- No configuration

**Better Pattern:**
```ruby
class ApplicationMailer < ActionMailer::Base
  default from: ENV['MAILER_FROM_ADDRESS'] || 'noreply@propertywebbuilder.com',
          reply_to: ENV['MAILER_REPLY_TO']
  
  layout "mailer"
  
  before_action :set_mailer_context
  
  rescue_from StandardError do |e|
    Rails.logger.error("Mailer error: #{e.class} - #{e.message}")
    # Could re-raise, queue for retry, or notify via Sentry
  end
  
  private
  
  def set_mailer_context
    @website = Pwb::Current.website
    @base_url = @website&.primary_domain || "example.com"
  end
end
```

---

## Template Architecture

### Current Multi-Tenant Approach

**Templates per scenario:**
```
app/views/pwb/mailers/
├── general_enquiry_targeting_agency.html.erb
└── property_enquiry_targeting_agency.html.erb
```

**Issue:** Only HTML templates, no text-only fallback

**Better Pattern:**
```
app/views/pwb/mailers/
├── general_enquiry_targeting_agency/
│   ├── _header.html.erb          # shared component
│   ├── _footer.html.erb          # shared component
│   ├── general_enquiry.html.erb  # main template
│   └── general_enquiry.text.erb  # text version
├── property_enquiry_targeting_agency/
│   ├── property_enquiry.html.erb
│   └── property_enquiry.text.erb
└── shared/
    ├── header.html.erb
    └── footer.html.erb
```

### Layout Deficiency

**Current (`mailer.html.erb`):**
```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      /* Empty */
    </style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

**Missing:**
- CSS for styling (needs inline styles for email clients)
- Mobile responsiveness
- Text color definitions
- Font specifications
- No fallback fonts

**Better Pattern:**
```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
      .email-container { max-width: 600px; margin: 0 auto; }
      .button { display: inline-block; padding: 12px 24px; background: #007bff; }
      /* More email-safe CSS */
    </style>
  </head>
  <body>
    <div class="email-container">
      <%= yield %>
    </div>
  </body>
</html>
```

---

## Delivery Architecture

### Current Synchronous Pattern

```
Request Timeline:
0ms    ─── HTTP request received
5ms    ─── Contact & Message created
10ms   ─── Mailer instantiated
50ms   ─── SMTP connection established
100ms  ─── Email rendered
500ms  ─── SMTP transmission
550ms  ─── HTTP 200 response sent
```

**Problem:** User waits ~550ms for emails to send

### Recommended Async Pattern

```
Request Timeline:
0ms    ─── HTTP request received
5ms    ─── Contact & Message created
20ms   ─── Email delivery job enqueued
30ms   ─── HTTP 200 response sent

Background Job (in worker process):
0ms    ─── Job starts
50ms   ─── SMTP connection
500ms  ─── Email sent
505ms  ─── Success logged
```

**Benefit:** HTTP response in 30ms instead of 550ms

---

## Error Handling Patterns

### Current (None)
```ruby
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now
# If SMTP fails: exception bubbles up, caught by generic rescue in controller
```

### Better Pattern (in Job)
```ruby
class SendEnquiryEmailJob < ApplicationJob
  queue_as :mailers
  
  # Retry with exponential backoff on transient errors
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  # Give up on permanent failures
  discard_on ActionMailer::MessageDeliveryError
  
  def perform(message_id)
    message = Pwb::Message.find(message_id)
    contact = message.contact
    
    EnquiryMailer.general_enquiry_targeting_agency(contact, message)
      .deliver_now
    
    # Track success
    message.update(delivery_status: :sent, delivery_timestamp: Time.current)
  rescue StandardError => e
    # Log for monitoring
    Rails.logger.error("Email delivery failed: #{e.message}")
    message.update(delivery_status: :failed, delivery_error: e.message)
    raise  # Will retry or discard based on job config
  end
end
```

---

## Configuration Architecture

### Current Issues

1. **SMTP Commented Out in Production**
   - Suggests uncertainty or incomplete setup
   - Will cause production email failure

2. **Placeholder Devise Sender**
   - "please-change-me-at-config-initializers-devise@example.com"
   - Not production-ready

3. **No Environment Variable Pattern**
   - Hard-coded values instead of `ENV['SMTP_ADDRESS']`
   - Reduces security and deployment flexibility

### Better Configuration Pattern

**config/initializers/action_mailer.rb**
```ruby
# Centralized ActionMailer configuration
Rails.application.config.tap do |config|
  config.action_mailer.default_url_options = {
    host: ENV['MAILER_HOST'] || 'localhost',
    protocol: ENV['MAILER_PROTOCOL'] || 'https'
  }
  
  if Rails.env.production?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV['SMTP_ADDRESS'],
      port: ENV['SMTP_PORT'].to_i,
      user_name: ENV['SMTP_USER'],
      password: ENV['SMTP_PASSWORD'],
      authentication: ENV['SMTP_AUTH'] || 'plain',
      enable_starttls_auto: ENV['SMTP_TLS'] != 'false'
    }
  elsif Rails.env.test?
    config.action_mailer.delivery_method = :test
  elsif Rails.env.development?
    config.action_mailer.delivery_method = :letter_opener
  end
end
```

---

## Multi-Tenancy Pattern

### Current Implementation

```
Message
  ├─ website_id (tenant key)
  ├─ contact_id
  └─ delivery_email (from agency)

Agency
  ├─ website_id (tenant key)
  ├─ email_for_general_contact_form
  └─ email_for_property_contact_form
```

### Good Aspects
- Proper tenant scoping
- Per-website contact configuration
- No cross-tenant leakage

### Enhancement Opportunity

**Add website context to mailer:**
```ruby
def general_enquiry_targeting_agency(contact, message)
  @website = message.website  # Add this
  @contact = contact
  @message = message
  @agency = @website.agency
  
  # Use website-specific branding in templates
  mail(
    to: message.delivery_email,
    from: @website.mailer_from_address,
    subject: @message.title.presence || 
             I18n.t("mailers.general_enquiry_targeting_agency.title", 
                    locale: @website.default_locale)
  )
end
```

**In template:**
```erb
<p>Enquiry received for: <%= @agency.company_name %></p>
```

---

## Performance Considerations

### Current Synchronous Impact

```
If SMTP is slow (1 second per email):
- 1 contact form = +1 second added latency
- During traffic spike: many slow emails = many slow requests
- Could overwhelm workers
```

### Queue-Based Async Impact

```
With background job queue:
- Request completes in ~30ms
- Worker process handles email separately
- Requests always fast
- Better resource utilization
```

### Scalability

```
Synchronous (Current):
- Rails workers: 4-8 processes
- Concurrent requests: 4-8 limited by SMTP speed
- Database queries: fast (contact/message create)
- Bottleneck: SMTP server

Asynchronous (Recommended):
- Rails workers: 4-8 processes (fast HTTP response)
- Job workers: separate processes for email
- Concurrent requests: not limited by SMTP
- Bottleneck: SMTP queue backlog (not request handling)
```

---

## Testing Architecture

### Current Test Approach

```ruby
# spec/mailers/pwb/enquiry_mailer_spec.rb
describe 'general enquiry' do
  let(:contact) { Contact.new(...) }
  let(:message) { Message.new(...) }
  let(:mail) { EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_now }
  
  it "sends enquiry successfully" do
    expect(mail.subject).to eq("General enquiry from your website")
  end
end
```

**Issues:**
- No failure scenarios
- No retry logic testing
- No async job testing
- No integration testing (form → email)

### Better Test Architecture

```ruby
describe Pwb::EnquiryMailer do
  describe '#general_enquiry_targeting_agency' do
    let(:website) { FactoryBot.create(:pwb_website) }
    let(:contact) { FactoryBot.create(:pwb_contact, website: website) }
    let(:message) { FactoryBot.create(:pwb_message, contact: contact, website: website) }
    
    context 'successful delivery' do
      it 'renders email correctly' do
        email = described_class.general_enquiry_targeting_agency(contact, message)
        expect(email.to).to eq([message.delivery_email])
        expect(email.subject).to be_present
        expect(email.body).to include(contact.first_name)
      end
      
      it 'includes all required information' do
        email = described_class.general_enquiry_targeting_agency(contact, message)
        expect(email.body.to_s).to include(message.content)
        expect(email.body.to_s).to include(contact.primary_phone_number)
      end
    end
    
    context 'with missing delivery email' do
      before { message.delivery_email = nil }
      
      it 'uses default address' do
        # Should handle gracefully
      end
    end
  end
  
  describe SendEnquiryEmailJob do
    it 'delivers email from background job' do
      message = create(:pwb_message)
      expect {
        SendEnquiryEmailJob.perform_now(message.id)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
    
    it 'retries on temporary failure' do
      # Test retry mechanism
    end
    
    it 'updates delivery status on success' do
      message = create(:pwb_message)
      SendEnquiryEmailJob.perform_now(message.id)
      expect(message.reload.delivery_status).to eq('sent')
    end
  end
end
```

---

## Security Considerations

### Input Validation Needed

1. **Email Address Validation**
   ```ruby
   # In Message/Contact models
   validates :origin_email, :delivery_email, format: { with: URI::MailTo::EMAIL_REGEXP }
   ```

2. **Header Injection Prevention**
   ```ruby
   # Email addresses used in mail() are automatically escaped by ActionMailer
   # But worth validating input
   
   def general_enquiry_targeting_agency(contact, message)
     # Rails automatically escapes email addresses in mail() parameters
     # to prevent header injection
     mail(to: message.delivery_email, ...)
   end
   ```

3. **Content Sanitization**
   ```ruby
   # Template rendering auto-escapes by default
   <!-- Safe: -->
   <%= @message.content %>
   
   <!-- Only use html_safe if you trust the source: -->
   <%# Don't do this unless content is trusted: %>
   <%#= @message.content.html_safe %>
   ```

4. **Rate Limiting**
   ```ruby
   # Not implemented - should add to controller
   class ContactUsController < ApplicationController
     before_action :rate_limit_contact_form, only: :contact_us_ajax
     
     private
     
     def rate_limit_contact_form
       throttle_ip = request.ip
       # Use Redis/Memcached to track IP submissions per minute
     end
   end
   ```

---

## Monitoring & Observability

### What's Tracked Today
- Nothing (no delivery_success updates)

### What Should Be Tracked

```ruby
# Suggested monitoring additions
class Pwb::Message < ApplicationRecord
  # Current: delivery_success (boolean, not updated)
  
  # Better: enum state machine
  enum delivery_status: { 
    pending: 0, 
    sent: 1, 
    failed: 2, 
    bounced: 3 
  }
  
  scope :failed_deliveries, -> { where(delivery_status: :failed) }
  scope :pending_retry, -> { where(delivery_status: :pending).where('created_at < ?', 1.hour.ago) }
end

# Monitoring dashboard metrics
# - Delivery success rate: sent / (sent + failed)
# - Average delivery time
# - Failed deliveries by error type
# - Bounce rate
# - Retry success rate
```

---

## Summary: Design Strengths & Weaknesses

### Strengths ✓
- Clean separation: Models, Controllers, Mailers
- Multi-tenant aware
- Flexible configuration per website
- Good test coverage basics
- i18n support

### Weaknesses ✗
- Synchronous delivery blocks requests
- No error handling
- No delivery tracking
- SMTP not configured (production blocker)
- No retry mechanism
- No text-only email versions
- Missing monitoring/observability

### Recommended Refactoring Priority
1. **Critical:** Add background job for email delivery
2. **High:** Configure SMTP & add error handling
3. **High:** Add delivery tracking (enum status)
4. **Medium:** Add text email versions
5. **Medium:** Implement rate limiting
6. **Low:** Add monitoring/analytics

---

## Architecture Decision: Sync vs Async

### Sync (Current)
```
Pros:
- Simpler code
- Immediate feedback if email fails
- Fewer moving parts

Cons:
- Blocks HTTP requests
- Poor user experience
- Harder to handle failures gracefully
- Difficult to scale
```

### Async (Recommended)
```
Pros:
- Non-blocking HTTP requests
- Better user experience
- Easier to retry on failure
- Better resource utilization
- Easier to monitor/alert

Cons:
- Requires job queue infrastructure
- Slightly more complex
- Email delivery is eventually consistent
```

**Recommendation:** Migrate to async with Sidekiq or similar

---

