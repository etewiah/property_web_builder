# Error Handling and Logging Analysis

## Executive Summary

PropertyWebBuilder has a **StructuredLogger** service in place, but it is **underutilized** across the codebase. Most critical operations lack comprehensive error logging context. This analysis identifies areas where logging improvements would significantly improve operational visibility, especially for multi-tenant operations.

**Key Finding**: The application has good audit logging for authentication (AuthAuditLog), but lacks comprehensive error logging in:
- Service classes handling critical operations
- External API integrations
- Email delivery operations
- Database operations that might silently fail
- Multi-tenant data isolation violations

---

## Critical Issues by Priority

### HIGH PRIORITY

#### 1. **Firebase Auth Service - Missing Error Context**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_auth_service.rb`
**Lines**: 8-50

**Issue**: While there is good logging for token verification, the following operations lack proper error context:
- User creation from Firebase token (line 38-47) - no logging if `user.save!` fails
- UserMembershipService.grant_access call (line 44) - wrapped in `save!` but errors not logged with context
- Email user lookup (line 34) - if multiple users exist with same email, creates ambiguity

**Impact**: 
- Authentication failures may be impossible to debug in production
- User provisioning failures during signup flow are lost
- Multi-tenant issues with user/email conflicts go unnoticed

**Required Improvements**:
```ruby
# Add logging for critical user creation
user.save!
StructuredLogger.info('Firebase user created', 
  firebase_uid: uid, 
  email: email,
  website_id: website.id)

# Add error handling for membership grant
rescue => e
  StructuredLogger.error('Failed to grant membership', 
    user_id: user.id,
    website_id: website.id,
    error: e.message,
    backtrace: e.backtrace.first(5))
```

---

#### 2. **Signup Flow - Silent Provisioning Failures**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/provisioning_service.rb`
**Lines**: 139-165

**Issue**: The `provision_website` method has error handling but lacks granular operation logging:
- No logging for individual configuration steps (lines 141-155)
- Database transaction failures absorbed but not traced with operational context
- Seed pack failures fall back silently without logging (lines 205-209)

**Impact**:
- Website provisioning failures leave no trace of which step failed
- Seed pack failures cause incomplete website setup
- Difficult to debug customer onboarding issues

**Required Improvements**:
```ruby
# Add step-by-step logging
website.start_configuring!
StructuredLogger.info('Provisioning step: configuring', 
  website_id: website.id,
  user_id: owner.id)

# Add context to seed pack fallback
rescue Pwb::SeedPack::PackNotFoundError => e
  StructuredLogger.warn('Seed pack not found, using fallback',
    pack_name: pack_name,
    website_id: website.id,
    error: e.message)
```

---

#### 3. **Contact Form Submission - Broad Exception Handling**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/contact_us_controller.rb`
**Lines**: 64-75

**Issue**: The `contact_us_ajax` action catches all exceptions with `rescue => e` but:
- Only returns generic error message, loses error details
- Email delivery failures not distinguished from form validation failures
- No context about which operation failed (save vs email vs ntfy)

**Current Code**:
```ruby
rescue => e
  @error_messages = [I18n.t("contact.error"), e]
  return render "pwb/ajax/contact_us_errors", layout: false
end
```

**Impact**:
- Lost inquiry records from validation failures
- Silent email delivery failures (customer doesn't know contact couldn't reach them)
- No alerting for notification system failures

**Required Improvements**:
```ruby
rescue => e
  StructuredLogger.error('Contact form submission failed',
    error_class: e.class.name,
    error_message: e.message,
    contact_id: @contact.id,
    message_id: @enquiry.id,
    step: 'form_submission')  # or 'contact_save', 'enquiry_save', 'email_delivery'
  
  # Distinguish between validation and delivery errors
  if @contact.invalid? || @enquiry.invalid?
    StructuredLogger.info('Validation failed', errors: @contact.errors.full_messages + @enquiry.errors.full_messages)
  else
    # Must be email/ntfy failure - should alert
    StructuredLogger.error('Post-submission delivery failed', ...)
  end
end
```

---

#### 4. **NtfyService - Network Errors Not Contextualized**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/ntfy_service.rb`
**Lines**: 199-205

**Issue**: The `perform_request` method catches StandardError broadly with minimal context:
- Network timeouts not distinguished from auth failures
- No retry information
- No context about which notification channel failed

**Current Code**:
```ruby
rescue StandardError => e
  Rails.logger.error("[NtfyService] Error sending notification: #{e.message}")
  false
end
```

**Impact**:
- Transient network failures treated same as configuration errors
- Impossible to set up monitoring for ntfy connectivity issues
- No ability to implement retry logic

**Required Improvements**:
```ruby
rescue Timeout::Error => e
  StructuredLogger.warn('Ntfy request timeout',
    topic: topic,
    website_id: website.id,
    timeout_seconds: http.read_timeout)
  false
rescue OpenSSL::SSL::SSLError => e
  StructuredLogger.error('Ntfy SSL error',
    topic: topic,
    website_id: website.id,
    error: e.message)
  false
rescue StandardError => e
  StructuredLogger.error('Ntfy unexpected error',
    topic: topic,
    website_id: website.id,
    error_class: e.class.name,
    error_message: e.message)
  false
end
```

---

#### 5. **Firebase Token Verification - Certificate Fetching Not Tracked**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/firebase_token_verifier.rb`
**Lines**: 76-96

**Issue**: The `fetch_certificates` method has error handling but no operational logging:
- No logging of successful certificate fetches
- No metrics on cache behavior
- Faraday errors logged only as CertificateError

**Current Code**:
```ruby
def fetch_certificates
  Rails.logger.info 'FirebaseTokenVerifier: Fetching certificates from Google'
  response = Faraday.get(CERTIFICATES_URL)
  unless response.success?
    raise CertificateError, "Failed to fetch certificates: HTTP #{response.status}"
  end
  # ... rest of method
rescue Faraday::Error => e
  raise CertificateError, "Network error fetching certificates: #{e.message}"
end
```

**Impact**:
- Certificate refresh failures cause all subsequent auth to fail
- No visibility into why Google cert endpoint fails
- Can't distinguish between network issues and API changes

**Required Improvements**:
```ruby
rescue Faraday::Error => e
  StructuredLogger.error('Firebase certificate fetch failed',
    error_class: e.class.name,
    error_message: e.message,
    certificate_url: CERTIFICATES_URL,
    is_retry: attempt_count > 0)
  raise CertificateError, ...
end
```

---

### MEDIUM PRIORITY

#### 6. **MLS Integration - No Error Logging**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/mls_connector.rb`

**Issue**: MLS connector performs RETS API calls with no error handling or logging:
- Lines 18-31: No exception handling for RETS client operations
- No timeouts configured
- No logging of RETS responses

**Impact**:
- Import failures cause silent failures or mysterious timeouts
- Difficult to debug MLS integration issues
- No metrics on import success rates

**Required Improvements**:
```ruby
def retrieve_via_rets(query, limit)
  StructuredLogger.info('Starting RETS query',
    import_source_id: import_source.id,
    query: query,
    limit: limit)
  
  client = Rets::Client.new(import_source.details)
  properties = client.find(quantity, {...})
  
  StructuredLogger.info('RETS query successful',
    import_source_id: import_source.id,
    property_count: properties.count)
  
  properties
rescue Rets::Errors::InvalidCredentials => e
  StructuredLogger.error('RETS authentication failed',
    import_source_id: import_source.id,
    error: e.message)
rescue Rets::Errors::ServerUnavailable => e
  StructuredLogger.warn('RETS server unavailable',
    import_source_id: import_source.id)
rescue StandardError => e
  StructuredLogger.error('RETS query failed',
    import_source_id: import_source.id,
    error_class: e.class.name,
    error_message: e.message,
    backtrace: e.backtrace.first(5))
  raise
end
```

---

#### 7. **Import Controllers - No Validation or Error Context**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/import/mls_controller.rb`
**Lines**: 7-23

**Issue**: 
- Parameter validation happens but provides no logging when missing (line 8-10)
- CSV parsing can fail silently (ImportProperties classes have no error handling)
- No logging of import statistics or failures

**Current Code**:
```ruby
%i[username password login_url mls_unique_name].each do |param_name|
  unless params[param_name].present?
    return render json: { error: "Please provide #{param_name}."}, status: 422
  end
end
```

**Impact**:
- Failed import attempts not logged
- No ability to track which MLS sources fail frequently
- CSV encoding issues go undetected

**Required Improvements**:
```ruby
def retrieve
  StructuredLogger.info('MLS import started',
    mls_name: params[:mls_unique_name],
    website_id: current_website&.id)
  
  # Validate parameters with logging
  required_params = %i[username password login_url mls_unique_name]
  missing = required_params.reject { |p| params[p].present? }
  
  if missing.any?
    StructuredLogger.warn('MLS import missing parameters',
      missing_params: missing)
    return render json: { error: "Please provide #{missing.join(', ')}" }, status: 422
  end
  
  # Log successful import
  StructuredLogger.info('MLS import completed',
    property_count: retrieved_properties.count,
    mls_name: params[:mls_unique_name])
rescue StandardError => e
  StructuredLogger.error('MLS import failed',
    error_class: e.class.name,
    error_message: e.message,
    mls_name: params[:mls_unique_name])
  render json: { error: 'Import failed' }, status: 500
end
```

---

#### 8. **User Membership Service - No Logging**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/services/pwb/user_membership_service.rb`
**Lines**: 1-30

**Issue**: All membership changes silently succeed or fail without logging:
- `grant_access` (lines 5-9) - no logging when membership created/updated
- `revoke_access` (lines 11-15) - returns false silently if membership not found
- `change_role` (lines 17-21) - raises ArgumentError but no context

**Impact**:
- Multi-tenant access control changes invisible
- Difficult to audit who has access to what website
- No alerting for revocation failures

**Required Improvements**:
```ruby
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
  StructuredLogger.error('Failed to grant membership',
    user_id: user.id,
    website_id: website.id,
    error: e.message)
  raise
end
```

---

#### 9. **Auth Audit Log - Creation Failure Not Surfaced**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/auth_audit_log.rb`
**Lines**: 198-200

**Issue**: The `create_log` method silently catches and suppresses all errors:
```ruby
rescue StandardError => e
  Rails.logger.error("[AuthAuditLog] Failed to create audit log: #{e.message}")
  nil
end
```

**Impact**:
- Audit logging failures go unnoticed
- Database issues not surfaced
- No alerting when audit trail is broken

**Better Approach**: Log the error but re-raise in critical contexts:
```ruby
rescue StandardError => e
  StructuredLogger.error('Auth audit log creation failed',
    event_type: event_type,
    user_id: user&.id,
    error_class: e.class.name,
    error_message: e.message,
    is_critical: event_type.in?(%w[login_failure account_locked]))
  
  # Re-raise for critical events to alert operations
  raise if %w[login_failure account_locked].include?(event_type)
  nil
end
```

---

### LOW PRIORITY

#### 10. **Firebase Login Controller - No Error Logging**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/firebase_login_controller.rb`

**Issue**: 
- No logging of password change requests (line 23)
- No logging of redirect decisions (line 35)
- Missing context logging for unauthenticated access attempts

**Improvement**: Add StructuredLogger calls around redirects and state changes.

---

#### 11. **User Model Callbacks - Swallowing Errors**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb`
**Lines**: 94-115

**Issue**: Both `log_registration` and `log_lockout_events` callbacks swallow exceptions:
```ruby
rescue StandardError => e
  Rails.logger.error("[AuthAuditLog] Failed to log lockout event: #{e.message}")
end
```

**Impact**: 
- User callbacks might fail to record important state
- Lockout events may not be logged

**Better Approach**: Use structured logging with severity levels.

---

#### 12. **Contact Form Email Delivery - No Specific Error Handling**
**File**: `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/contact_us_controller.rb`
**Lines**: 55-62

**Issue**: Email delivery is async via `.deliver_later` with no error handling:
```ruby
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later
```

**Impact**:
- Email delivery failures will be invisible to user
- No alerting when contact emails don't reach agency
- Users think message was sent when it may fail asynchronously

**Better Approach**: Log and monitor async job failures.

---

## Recommendations by Category

### 1. **Structured Logging Adoption**
- **Status**: StructuredLogger exists but is underutilized
- **Action**: Add logging to all critical service methods
- **Pattern**:
  ```ruby
  StructuredLogger.info('Operation started', context_fields)
  # ... operation ...
  StructuredLogger.info('Operation completed', result_fields)
  rescue StandardError => e
    StructuredLogger.error('Operation failed', error: e.message, context)
    raise
  end
  ```

### 2. **Error Context Preservation**
- **Action**: Always log with operational context before re-raising or returning false
- **Fields to Include**:
  - `website_id` / `tenant_id` for multi-tenant operations
  - `user_id` / `email` for auth operations
  - `operation_name` / `step` for multi-step processes
  - `error_class`, `error_message` for exceptions
  - `backtrace` (first 5 lines) for debugging

### 3. **External API Error Handling**
- **Services Affected**: Firebase, ntfy, MLS/RETS, Faraday calls
- **Action**: Distinguish error types (timeout, auth, network, parse, etc.)
- **Pattern**:
  ```ruby
  rescue Timeout::Error => e
    StructuredLogger.warn('Request timeout', operation, timeout_config)
    # Potentially retry
  rescue StandardError => e
    StructuredLogger.error('Unexpected error', operation, error_details)
    raise
  end
  ```

### 4. **Silent Failure Prevention**
- **Current Issues**:
  - Broad `rescue => e` with minimal logging
  - Methods returning false without context
  - Async operations not tracked
- **Action**: 
  - Add logging before suppressing errors
  - For silent failures, always log first with appropriate level (warn/error)
  - Consider AlertJob for critical operation failures

### 5. **Multi-Tenant Data Isolation Logging**
- **Current Gap**: No logging when multi-tenant scoping might fail
- **Action**: Add logging to:
  - User creation with website context
  - Website membership changes
  - Cross-website data access attempts

### 6. **Recommended Logging Checklist**
For each critical operation, ensure:
- [ ] Logging at start with input parameters
- [ ] Logging at successful completion
- [ ] Specific error handling (not broad catch-all)
- [ ] Error logging includes: error class, message, relevant IDs, operation context
- [ ] For external APIs: timeout, auth, and network errors handled separately

---

## Implementation Priority Order

1. **Phase 1 (Critical - Do First)**:
   - Firebase Auth Service error logging
   - Signup/Provisioning flow step logging
   - Contact form submission error context
   - ntfy Service network error handling

2. **Phase 2 (Important - Do Next)**:
   - MLS integration error handling
   - User membership service logging
   - Import controller logging
   - Auth audit log failure handling

3. **Phase 3 (Good to Have)**:
   - Firebase login controller logging
   - User model callback error logging
   - Email delivery monitoring

---

## Testing Recommendations

- Add tests verifying StructuredLogger calls in error paths
- Test that exceptions are properly logged with context
- Verify multi-tenant context is included in all critical logs
- Test external API error scenarios (timeout, auth failure, 5xx)
- Add fixtures for various error conditions

