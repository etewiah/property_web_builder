# Logging Quick Reference & Code Examples

## StructuredLogger API

The application already has `StructuredLogger` service available. Here's how to use it:

```ruby
# Basic logging by level
StructuredLogger.debug('Debug message', field1: value1)
StructuredLogger.info('Info message', field1: value1)
StructuredLogger.warn('Warning message', field1: value1)
StructuredLogger.error('Error message', field1: value1)
StructuredLogger.fatal('Fatal message', field1: value1)

# Exception logging (includes class, message, backtrace)
StructuredLogger.exception(error, 'Context message', user_id: 123)

# Performance/metrics logging
StructuredLogger.metric('user.created', value: 1, website_id: 456)
StructuredLogger.measure('expensive_operation') do
  # Code to measure
end

# Thread-local context (auto-included in all logs within block)
StructuredLogger.with_context(tenant_id: 123) do
  StructuredLogger.info('This log includes tenant_id automatically')
end
```

**Output**: Logs are JSON-formatted with fields:
```json
{
  "timestamp": "2025-12-11T10:30:45.123Z",
  "level": "ERROR",
  "message": "Operation failed",
  "environment": "production",
  "application": "property_web_builder",
  "tenant": { "id": 123, "subdomain": "test-agency" },
  "request_id": "abc-def-123",
  "user_id": 456,
  "custom_field": "value"
}
```

---

## Critical Fixes - Copy & Paste Ready

### 1. Firebase Auth Service

**File**: `app/services/pwb/firebase_auth_service.rb`

**Current (line 44-47)**:
```ruby
UserMembershipService.grant_access(
  user: user,
  website: website,
  role: 'member'
)
```

**Fixed**:
```ruby
begin
  UserMembershipService.grant_access(
    user: user,
    website: website,
    role: 'member'
  )
  Rails.logger.info("Firebase user fully provisioned", user_id: user.id, website_id: website.id)
rescue StandardError => e
  StructuredLogger.error("Failed to grant Firebase user membership",
    user_id: user.id,
    firebase_uid: uid,
    website_id: website.id,
    error_class: e.class.name,
    error_message: e.message,
    backtrace: e.backtrace.first(5))
  raise
end
```

---

### 2. Contact Form Controller

**File**: `app/controllers/pwb/contact_us_controller.rb`

**Current (line 64-75)**:
```ruby
rescue => e
  @error_messages = [I18n.t("contact.error"), e]
  return render "pwb/ajax/contact_us_errors", layout: false
end
```

**Fixed**:
```ruby
rescue => e
  # Log with context before responding
  error_context = {
    error_class: e.class.name,
    error_message: e.message,
    contact_saved: !@contact.invalid?,
    enquiry_saved: !@enquiry.invalid?,
    has_validation_errors: @contact.invalid? || @enquiry.invalid?
  }
  
  if @contact.invalid? || @enquiry.invalid?
    StructuredLogger.warn('Contact form validation failed',
      error_context.merge(
        contact_errors: @contact.errors.full_messages,
        enquiry_errors: @enquiry.errors.full_messages))
  else
    # Saved but delivery failed
    StructuredLogger.error('Contact form submission failed after save',
      error_context.merge(
        contact_id: @contact.id,
        message_id: @enquiry&.id))
  end
  
  @error_messages = [I18n.t("contact.error"), e]
  return render "pwb/ajax/contact_us_errors", layout: false
end
```

---

### 3. NtfyService Network Error Handling

**File**: `app/services/ntfy_service.rb`

**Current (line 199-205)**:
```ruby
rescue StandardError => e
  Rails.logger.error("[NtfyService] Error sending notification: #{e.message}")
  false
end
```

**Fixed**:
```ruby
rescue Timeout::Error, Errno::ETIMEDOUT => e
  StructuredLogger.warn('NtfyService timeout',
    topic: topic,
    website_id: website&.id,
    channel: channel,
    timeout_seconds: http.read_timeout)
  false
  
rescue OpenSSL::SSL::SSLError => e
  StructuredLogger.error('NtfyService SSL error',
    topic: topic,
    website_id: website&.id,
    channel: channel,
    error_message: e.message)
  false
  
rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
  StructuredLogger.warn('NtfyService connection refused',
    topic: topic,
    website_id: website&.id,
    channel: channel,
    server_url: server_url)
  false
  
rescue StandardError => e
  StructuredLogger.error('NtfyService unexpected error',
    error_class: e.class.name,
    error_message: e.message,
    topic: topic,
    website_id: website&.id,
    channel: channel,
    backtrace: e.backtrace.first(5))
  false
end
```

---

### 4. Provisioning Service - Step Logging

**File**: `app/services/pwb/provisioning_service.rb`

**Add to `provision_website` method (around line 141)**:
```ruby
def provision_website(website:, &progress_block)
  @errors = []
  
  StructuredLogger.info('Website provisioning started',
    website_id: website.id,
    provisioning_state: website.provisioning_state,
    seed_pack: website.seed_pack_name)

  begin
    # Start configuring
    website.start_configuring!
    StructuredLogger.info('Provisioning step: started configuring',
      website_id: website.id)
    report_progress(progress_block, website, 'configuring', 40)

    # Apply base configuration
    configure_website_defaults(website)
    StructuredLogger.info('Provisioning step: configured defaults',
      website_id: website.id,
      theme: website.theme_name)

    # Start seeding
    website.start_seeding!
    StructuredLogger.info('Provisioning step: started seeding',
      website_id: website.id)
    report_progress(progress_block, website, 'seeding', 70)

    # Run seed pack
    run_seed_pack(website)
    StructuredLogger.info('Provisioning step: seed pack applied',
      website_id: website.id,
      seed_pack: website.seed_pack_name)

    # Mark ready
    website.mark_ready!
    StructuredLogger.info('Provisioning step: marked ready',
      website_id: website.id)
    report_progress(progress_block, website, 'ready', 95)

    # Auto-go-live
    website.go_live!
    StructuredLogger.info('Provisioning step: gone live',
      website_id: website.id)
    report_progress(progress_block, website, 'live', 100)

    # Complete user onboarding
    owner = website.user_memberships.find_by(role: 'owner')&.user
    if owner
      owner.update!(onboarding_step: 4)
      owner.activate! if owner.may_activate?
      StructuredLogger.info('Provisioning step: owner activated',
        website_id: website.id,
        user_id: owner.id)
    end

    StructuredLogger.info('Website provisioning completed',
      website_id: website.id)
    success_result(website: website)
      
  rescue StandardError => e
    StructuredLogger.error('Website provisioning failed',
      website_id: website.id,
      provisioning_state: website.provisioning_state,
      error_class: e.class.name,
      error_message: e.message,
      backtrace: e.backtrace.first(10))

    website.fail_provisioning!(e.message) if website.may_fail_provisioning?
    @errors << "Provisioning failed: #{e.message}"
    failure_result
  end
end
```

---

### 5. Firebase Token Verifier - Certificate Fetch Logging

**File**: `app/services/pwb/firebase_token_verifier.rb`

**Current (line 76-96)**:
```ruby
def fetch_certificates
  Rails.logger.info 'FirebaseTokenVerifier: Fetching certificates from Google'
  response = Faraday.get(CERTIFICATES_URL)
  unless response.success?
    raise CertificateError, "Failed to fetch certificates: HTTP #{response.status}"
  end
  # ... rest
rescue Faraday::Error => e
  raise CertificateError, "Network error fetching certificates: #{e.message}"
end
```

**Fixed**:
```ruby
def fetch_certificates
  StructuredLogger.info('Firebase certificates fetch started',
    url: CERTIFICATES_URL)
  
  response = Faraday.get(CERTIFICATES_URL)
  
  unless response.success?
    StructuredLogger.error('Firebase certificates fetch failed',
      http_status: response.status,
      response_body: response.body.truncate(500))
    raise CertificateError, "Failed to fetch certificates: HTTP #{response.status}"
  end
  
  # Parse cache-control header for TTL
  cache_control = response.headers['cache-control']
  if cache_control && (match = cache_control.match(/max-age=(\d+)/))
    ttl = match[1].to_i.seconds
    certificates = JSON.parse(response.body)
    Rails.cache.write(CACHE_KEY, certificates, expires_in: ttl)
    StructuredLogger.info('Firebase certificates cached',
      ttl_seconds: ttl,
      certificate_count: certificates.count)
    return certificates
  end

  JSON.parse(response.body)
  
rescue Faraday::ConnectionFailed => e
  StructuredLogger.error('Firebase certificates fetch - connection failed',
    error_class: e.class.name,
    error_message: e.message)
  raise CertificateError, "Network error fetching certificates: #{e.message}"
  
rescue Faraday::TimeoutError => e
  StructuredLogger.warn('Firebase certificates fetch - timeout',
    error_message: e.message)
  raise CertificateError, "Timeout fetching certificates: #{e.message}"
  
rescue JSON::ParserError => e
  StructuredLogger.error('Firebase certificates fetch - invalid JSON',
    error_message: e.message)
  raise CertificateError, "Invalid JSON in certificates response: #{e.message}"
  
rescue StandardError => e
  StructuredLogger.error('Firebase certificates fetch - unexpected error',
    error_class: e.class.name,
    error_message: e.message)
  raise
end
```

---

### 6. MLS Connector - Error Handling

**File**: `app/services/pwb/mls_connector.rb`

**Add throughout**:
```ruby
def retrieve(query, limit)
  unless import_source.source_type == "rets"
    StructuredLogger.error('Invalid MLS source type',
      import_source_id: import_source.id,
      source_type: import_source.source_type)
    raise ArgumentError, "Unsupported source type: #{import_source.source_type}. Only RETS is supported."
  end

  retrieve_via_rets(query, limit)
end

private

def retrieve_via_rets(query, limit)
  StructuredLogger.info('MLS RETS query started',
    import_source_id: import_source.id,
    query: query,
    limit: limit)
  
  client = Rets::Client.new(import_source.details)
  
  properties = client.find(:all, {
    search_type: 'Property',
    class: import_source.default_property_class,
    query: query,
    limit: limit
  })
  
  StructuredLogger.info('MLS RETS query successful',
    import_source_id: import_source.id,
    property_count: properties.count)
  
  properties
  
rescue Rets::Errors::InvalidCredentials => e
  StructuredLogger.error('MLS RETS authentication failed',
    import_source_id: import_source.id,
    error_message: e.message)
  raise
  
rescue Rets::Errors::ServerUnavailable => e
  StructuredLogger.warn('MLS RETS server unavailable',
    import_source_id: import_source.id)
  raise
  
rescue Timeout::Error => e
  StructuredLogger.warn('MLS RETS request timeout',
    import_source_id: import_source.id)
  raise
  
rescue StandardError => e
  StructuredLogger.error('MLS RETS query failed',
    import_source_id: import_source.id,
    error_class: e.class.name,
    error_message: e.message,
    backtrace: e.backtrace.first(5))
  raise
end
```

---

### 7. User Membership Service - Add Logging

**File**: `app/services/pwb/user_membership_service.rb`

**Replace entire class**:
```ruby
module Pwb
  class UserMembershipService
    class << self
      def grant_access(user:, website:, role: 'member')
        membership = UserMembership.find_or_initialize_by(user: user, website: website)
        was_new = membership.new_record?
        
        membership.role = role
        membership.active = true
        membership.save!
        
        StructuredLogger.info('User membership granted',
          user_id: user.id,
          website_id: website.id,
          role: role,
          is_new: was_new)
        
        membership
        
      rescue StandardError => e
        StructuredLogger.error('Failed to grant user membership',
          user_id: user.id,
          website_id: website.id,
          role: role,
          error_class: e.class.name,
          error_message: e.message)
        raise
      end

      def revoke_access(user:, website:)
        membership = UserMembership.find_by(user: user, website: website)
        
        unless membership
          StructuredLogger.warn('Cannot revoke access - membership not found',
            user_id: user.id,
            website_id: website.id)
          return false
        end
        
        membership.update!(active: false)
        
        StructuredLogger.info('User membership revoked',
          user_id: user.id,
          website_id: website.id,
          membership_id: membership.id)
        
        true
        
      rescue StandardError => e
        StructuredLogger.error('Failed to revoke user membership',
          user_id: user.id,
          website_id: website.id,
          error_class: e.class.name,
          error_message: e.message)
        raise
      end

      def change_role(user:, website:, new_role:)
        unless UserMembership::ROLES.include?(new_role)
          StructuredLogger.warn('Invalid role for membership change',
            user_id: user.id,
            website_id: website.id,
            requested_role: new_role,
            valid_roles: UserMembership::ROLES)
          raise ArgumentError, "Invalid role: #{new_role}"
        end
        
        membership = UserMembership.find_by!(user: user, website: website)
        old_role = membership.role
        
        membership.update!(role: new_role)
        
        StructuredLogger.info('User membership role changed',
          user_id: user.id,
          website_id: website.id,
          old_role: old_role,
          new_role: new_role)
        
        membership
        
      rescue StandardError => e
        StructuredLogger.error('Failed to change user role',
          user_id: user.id,
          website_id: website.id,
          requested_role: new_role,
          error_class: e.class.name,
          error_message: e.message)
        raise
      end

      def list_user_websites(user:, role: nil)
        scope = user.user_memberships.active.includes(:website)
        scope = scope.where(role: role) if role
        scope.map(&:website)
      end
      
      def list_website_users(website:, role: nil)
        scope = website.user_memberships.active.includes(:user)
        scope = scope.where(role: role) if role
        scope.map(&:user)
      end
    end
  end
end
```

---

## Common Logging Patterns

### Pattern 1: Critical Operation with Step Logging
```ruby
def critical_operation
  StructuredLogger.info('Operation started', operation_id: SecureRandom.uuid)
  
  step_1_result = perform_step_1
  StructuredLogger.info('Step 1 completed', result_summary)
  
  step_2_result = perform_step_2
  StructuredLogger.info('Step 2 completed', result_summary)
  
  StructuredLogger.info('Operation completed successfully', final_result)
  final_result
  
rescue => e
  StructuredLogger.error('Operation failed at step X',
    error_class: e.class.name,
    error_message: e.message,
    backtrace: e.backtrace.first(5))
  raise
end
```

### Pattern 2: External API Call
```ruby
def call_external_api(params)
  StructuredLogger.info('Calling external API',
    endpoint: 'https://api.example.com/v1',
    params: params.except(:password))
  
  response = api_client.request(params)
  
  StructuredLogger.info('API call successful',
    status: response.status,
    response_time_ms: response.timing)
  
  response
  
rescue Timeout::Error => e
  StructuredLogger.warn('API timeout',
    endpoint: 'https://api.example.com/v1',
    timeout_seconds: 30)
  # Handle gracefully
  
rescue StandardError => e
  StructuredLogger.error('API call failed',
    endpoint: 'https://api.example.com/v1',
    error_class: e.class.name,
    error_message: e.message)
  raise
end
```

### Pattern 3: Async Job with Error Handling
```ruby
class MyJob < ApplicationJob
  def perform(record_id)
    StructuredLogger.info('Job started',
      job_class: self.class.name,
      record_id: record_id)
    
    record = MyModel.find(record_id)
    perform_work(record)
    
    StructuredLogger.info('Job completed',
      job_class: self.class.name,
      record_id: record_id)
    
  rescue StandardError => e
    StructuredLogger.error('Job failed',
      job_class: self.class.name,
      record_id: record_id,
      error_class: e.class.name,
      error_message: e.message,
      backtrace: e.backtrace.first(5))
    
    # Re-raise for job retry, or handle gracefully
    raise
  end
end
```

---

## Fields to Always Include

When logging, include these fields for better context:

| Field | Use Case | Example |
|-------|----------|---------|
| `website_id` / `tenant_id` | Multi-tenant operations | `website_id: 123` |
| `user_id` | User-related operations | `user_id: 456` |
| `email` | Auth operations | `email: "user@example.com"` |
| `error_class` | Exception handling | `error_class: "ActiveRecord::RecordNotFound"` |
| `error_message` | Exception handling | `error_message: "Record not found"` |
| `backtrace` | Debugging | `backtrace: e.backtrace.first(5)` |
| `operation_name` | Multi-step operations | `operation: "provisioning"` |
| `step` | Which step in process | `step: "configuring_theme"` |
| `duration_ms` | Performance | `duration_ms: 1234` |
| `count` | Results | `property_count: 50` |

