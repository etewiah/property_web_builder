# Logging Implementation Checklist

Use this checklist to track implementation of logging improvements.

## Phase 1: Critical Path (Signup & Auth)

### 1. Firebase Auth Service
- [ ] File: `app/services/pwb/firebase_auth_service.rb`
- [ ] Lines: 38-47 (membership grant)
- [ ] Task: Add error logging for user creation and membership grant
- [ ] Add: `StructuredLogger.error` with user_id, website_id, error_class
- [ ] Test: Mock UserMembershipService to fail, verify logging
- [ ] Priority: CRITICAL
- [ ] Estimated: 15 min
- [ ] Status: ___________

### 2. Provisioning Service - Step Logging
- [ ] File: `app/services/pwb/provisioning_service.rb`
- [ ] Lines: 139-165 (provision_website method)
- [ ] Task: Add logging for each provisioning step
- [ ] Add: StructuredLogger calls before/after each major step
- [ ] Add: Error logging with full backtrace and context
- [ ] Add: Step name in error logs (configuring, seeding, etc.)
- [ ] Test: Trigger failures at each step, verify logs
- [ ] Priority: CRITICAL
- [ ] Estimated: 30 min
- [ ] Status: ___________

### 3. Seed Pack Fallback Logging
- [ ] File: `app/services/pwb/provisioning_service.rb`
- [ ] Lines: 205-209 (run_seed_pack rescue)
- [ ] Task: Add logging for seed pack failures and fallback
- [ ] Add: `StructuredLogger.warn` when seed pack not found
- [ ] Add: `StructuredLogger.warn` when seed pack fails
- [ ] Test: Test with non-existent seed pack name
- [ ] Priority: CRITICAL
- [ ] Estimated: 10 min
- [ ] Status: ___________

### 4. Contact Form Exception Handling
- [ ] File: `app/controllers/pwb/contact_us_controller.rb`
- [ ] Lines: 64-75 (contact_us_ajax rescue)
- [ ] Task: Replace broad exception handling with context
- [ ] Add: Distinguish validation vs delivery errors
- [ ] Add: Log contact_id and message_id for tracking
- [ ] Add: Context about which step failed
- [ ] Test: Trigger validation failures, save failures, delivery failures
- [ ] Priority: CRITICAL
- [ ] Estimated: 20 min
- [ ] Status: ___________

### 5. NtfyService Network Error Handling
- [ ] File: `app/services/ntfy_service.rb`
- [ ] Lines: 199-205 (perform_request rescue)
- [ ] Task: Handle different error types specifically
- [ ] Add: Timeout::Error handling
- [ ] Add: SSL error handling
- [ ] Add: Connection refused handling
- [ ] Add: Generic error handling
- [ ] Test: Mock Faraday to raise different exceptions
- [ ] Priority: CRITICAL
- [ ] Estimated: 20 min
- [ ] Status: ___________

## Phase 2: Support Systems

### 6. MLS Connector Error Handling
- [ ] File: `app/services/pwb/mls_connector.rb`
- [ ] Lines: Full file (18-31)
- [ ] Task: Add comprehensive error handling
- [ ] Add: Starting log with import_source_id and query
- [ ] Add: Success log with property count
- [ ] Add: Specific handlers for Rets::Errors
- [ ] Add: Timeout handling
- [ ] Add: Generic error logging with backtrace
- [ ] Test: Mock RETS client to raise each error type
- [ ] Priority: IMPORTANT
- [ ] Estimated: 25 min
- [ ] Status: ___________

### 7. User Membership Service Logging
- [ ] File: `app/services/pwb/user_membership_service.rb`
- [ ] Lines: Full file (5-30)
- [ ] Task: Add logging to all membership operations
- [ ] Add: Log grant_access with is_new flag
- [ ] Add: Log revoke_access with result
- [ ] Add: Log change_role with old_role and new_role
- [ ] Add: Error logging with full context
- [ ] Test: Call each method and verify logs
- [ ] Priority: IMPORTANT
- [ ] Estimated: 20 min
- [ ] Status: ___________

### 8. Auth Audit Log Failure Handling
- [ ] File: `app/models/pwb/auth_audit_log.rb`
- [ ] Lines: 198-200 (create_log rescue)
- [ ] Task: Handle audit log creation failures better
- [ ] Add: StructuredLogger instead of Rails.logger
- [ ] Add: Re-raise for critical events
- [ ] Add: is_critical flag based on event_type
- [ ] Test: Mock save to fail, verify re-raise for critical events
- [ ] Priority: IMPORTANT
- [ ] Estimated: 5 min
- [ ] Status: ___________

### 9. Firebase Token Verifier Certificate Fetch
- [ ] File: `app/services/pwb/firebase_token_verifier.rb`
- [ ] Lines: 76-96 (fetch_certificates)
- [ ] Task: Add comprehensive logging and error handling
- [ ] Add: Starting log with URL
- [ ] Add: Success log with TTL and certificate count
- [ ] Add: Specific handlers for Faraday errors
- [ ] Add: JSON parser error handling
- [ ] Test: Mock Faraday to raise different exceptions
- [ ] Priority: IMPORTANT
- [ ] Estimated: 20 min
- [ ] Status: ___________

### 10. Import Controller Parameter Validation
- [ ] File: `app/controllers/pwb/import/mls_controller.rb`
- [ ] Lines: 7-45 (retrieve method)
- [ ] Task: Add logging for import operations
- [ ] Add: Starting log with import parameters
- [ ] Add: Validation failure logging
- [ ] Add: Success logging with property count
- [ ] Add: Error logging with full context
- [ ] Test: Call with missing params, verify logging
- [ ] Priority: IMPORTANT
- [ ] Estimated: 15 min
- [ ] Status: ___________

## Phase 3: Refinement

### 11. Firebase Login Controller Logging
- [ ] File: `app/controllers/pwb/firebase_login_controller.rb`
- [ ] Lines: All (23-35)
- [ ] Task: Add logging for password changes and redirects
- [ ] Add: Log password change requests
- [ ] Add: Log redirect decisions
- [ ] Priority: NICE-TO-HAVE
- [ ] Estimated: 10 min
- [ ] Status: ___________

### 12. User Model Callbacks
- [ ] File: `app/models/pwb/user.rb`
- [ ] Lines: 94-115 (callback methods)
- [ ] Task: Improve callback error handling
- [ ] Add: Use StructuredLogger instead of Rails.logger
- [ ] Add: Context about which callback failed
- [ ] Priority: NICE-TO-HAVE
- [ ] Estimated: 10 min
- [ ] Status: ___________

### 13. Email Delivery Monitoring
- [ ] File: `app/controllers/pwb/contact_us_controller.rb`
- [ ] Lines: 55-62 (email delivery)
- [ ] Task: Add async job monitoring for email delivery
- [ ] Add: Log job ID when email is queued
- [ ] Add: Implement job failure handlers
- [ ] Priority: NICE-TO-HAVE
- [ ] Estimated: 15 min
- [ ] Status: ___________

## Testing Tasks

### Unit Tests
- [ ] Firebase auth service error cases
- [ ] Provisioning service failure scenarios
- [ ] Contact form validation and delivery failures
- [ ] NtfyService network error handling
- [ ] MLS connector RETS error handling
- [ ] User membership service all operations

### Integration Tests
- [ ] Full signup flow with provisioning failure
- [ ] Contact form submission with network error
- [ ] MLS import with connection failure

### Logging Verification
- [ ] All StructuredLogger calls use correct level (info/warn/error)
- [ ] All error logs include: error_class, error_message, backtrace
- [ ] All critical operations include: website_id or tenant_id
- [ ] No sensitive data logged (passwords, tokens, emails in critical logs)
- [ ] Multi-tenant context preserved across services

## Code Review Checklist

For each PR, verify:
- [ ] StructuredLogger used consistently
- [ ] Error context includes website_id/user_id
- [ ] Different error types handled distinctly
- [ ] No broad `rescue => e` without logging context
- [ ] Tests verify logging is called
- [ ] No sensitive data in logs
- [ ] Backtrace included for debugging (first 5 lines)
- [ ] Metric fields included (counts, timings, etc.)

## Deployment Checklist

### Pre-Deployment
- [ ] All Phase 1 tests passing
- [ ] Log aggregator configured for JSON parsing
- [ ] Team trained on new log fields
- [ ] Monitoring/alerting rules reviewed

### Deployment
- [ ] Deploy to staging first
- [ ] Trigger errors in staging, verify in logs
- [ ] Monitor production logs after deployment
- [ ] Check for any errors from new logging code

### Post-Deployment
- [ ] Sample logs in all environments
- [ ] Verify all new fields present
- [ ] Check error counts vs baseline
- [ ] Update runbooks with new log field examples

## Timeline

| Phase | Start | End | Duration | Items |
|-------|-------|-----|----------|-------|
| Phase 1 | Week 1 Mon | Week 1 Wed | 2 days | Items 1-5 |
| Phase 2 | Week 2 Mon | Week 2 Tue | 1.5 days | Items 6-10 |
| Phase 3 | Week 2 Wed | Week 2 Thu | 1 day | Items 11-13 |
| Testing | Throughout | End of Week 2 | Ongoing | Unit + Integration |
| Deployment | Week 3 | Week 3 | 1 day | Staging → Production |

**Total Estimated Effort**: ~8-10 hours of development + testing

## Sign-Off

- [ ] All items completed
- [ ] All tests passing
- [ ] Code reviewed
- [ ] Deployed to production
- [ ] Monitoring verified
- [ ] Team trained

**Completed by**: _________________ **Date**: _________________

**Reviewed by**: _________________ **Date**: _________________

