# Push Notifications Analysis for PropertyWebBuilder

## Executive Summary

PropertyWebBuilder is a multi-tenant real estate platform with several distinct areas where push notifications could add significant value. The application currently has a well-established email notification system via ActionMailer and has extensive audit logging for security events. Push notifications can complement these existing systems to provide real-time, in-app, and mobile alerts.

## Current Notification Infrastructure

### 1. Email System
- **Location**: `/app/mailers/pwb/enquiry_mailer.rb`
- **Methods**:
  - `general_enquiry_targeting_agency` - Sends general contact form enquiries to agency email
  - `property_enquiry_targeting_agency` - Sends property-specific enquiries to agency email
- **Trigger**: Used synchronously in contact form submissions (line 92 of contact_us_controller.rb via `deliver_now`)

### 2. Audit Logging
- **Location**: `/app/models/pwb/auth_audit_log.rb`
- **Comprehensive event tracking**:
  - login_success / login_failure
  - oauth_success / oauth_failure
  - password_reset_request / password_reset_success
  - account_locked / account_unlocked
  - session_timeout
  - registration
- **Multi-tenant support**: Logs associated with websites and users
- **Security queries**: Methods for detecting suspicious activity and failed attempts

### 3. Multi-Tenancy Architecture
- **Tenant Scoping**: Models use `website_id` foreign key for isolation
- **Tenant Models**: `PwbTenant::*` versions for web requests
- **Current Website Context**: `Pwb::Current.website` for tenant context
- **User Memberships**: Users can have roles (owner, admin, member) across multiple websites via `UserMembership` model

## High-Value Push Notification Opportunities

### 1. Contact Form Submissions / Inquiry Messages
**Priority**: HIGH
**Current State**: 
- Contact form creates `Pwb::Contact` and `Pwb::Message` records
- Emails sent via `EnquiryMailer.general_enquiry_targeting_agency`
- Two types: general enquiries and property-specific enquiries
- Admin can view messages in `/site_admin/messages` controller

**Push Notification Value**:
- Real-time alerts to admins when new inquiries arrive
- Property agents can be notified immediately of inquiries on specific properties
- Reduce response time and improve customer engagement
- Separate notifications for general vs. property-specific inquiries

**Integration Points**:
```
File: /app/controllers/pwb/contact_us_controller.rb (line 92)
Model: /app/models/pwb/message.rb
Controller: /app/controllers/site_admin/messages_controller.rb
```

**Key Data**:
- Message title, content, origin_email
- Associated contact information
- Website and property context
- Delivery email for routing

### 2. Property Listing Activations
**Priority**: HIGH
**Current State**:
- `SaleListing` and `RentalListing` models have activation callbacks
- Materialized view (`ListedProperty`) reflects active listings
- Admin can manage property visibility and highlight status
- Properties have associated websites

**Push Notification Value**:
- Notify property managers/agents when listings are activated
- Alert to available agents when new properties are listed
- Notify about property availability changes (active/inactive/archived)
- Feature highlights and pricing updates
- Vacation rental availability notifications

**Integration Points**:
```
Files:
- /app/models/pwb/rental_listing.rb (callbacks: before_save, after_commit)
- /app/models/pwb/sale_listing.rb (callbacks: before_save, after_commit)
- /app/models/pwb/listed_property.rb
```

**Key Data**:
- Property reference, address, city
- Price, bedrooms, bathrooms
- Rental type (short-term/long-term)
- Visibility and highlight status
- Website scope

### 3. User Registration & Account Events
**Priority**: MEDIUM-HIGH
**Current State**:
- User registration via Devise (registerable module)
- Audit logging via `after_create :log_registration` callback
- Support for multi-website user memberships
- Account lockout/unlock tracking
- Firebase auth support for cross-tenant users

**Push Notification Value**:
- Welcome notifications for new registrations
- Account security alerts (login failures, account locked, suspicious activity)
- Password reset confirmations
- Multi-website membership invitations
- Failed login attempt warnings
- Session timeout notifications

**Integration Points**:
```
Files:
- /app/models/pwb/user.rb (Devise, callbacks, auth audit logging)
- /app/models/pwb/auth_audit_log.rb (comprehensive logging)
- /app/models/pwb/user_membership.rb (multi-website access)
```

**Key Data**:
- User email, authentication provider
- IP address, user agent, request path
- Failed attempt reason
- Account lock status
- Assigned roles and websites

### 4. Admin Dashboard Activity
**Priority**: MEDIUM
**Current State**:
- Dashboard shows statistics and recent activity
- Tracked metrics: properties, pages, contents, messages, contacts
- Recent activity feeds with last 5 records

**Push Notification Value**:
- Real-time dashboard notifications
- Threshold alerts (e.g., "10+ inquiries received")
- Daily digest of website activity
- High-priority admin alerts

**Integration Points**:
```
File: /app/controllers/site_admin/dashboard_controller.rb
Queries: Message, Contact, ListedProperty, Page, Content counts
```

### 5. API-Based Interactions
**Priority**: MEDIUM
**Current State**:
- API v1 endpoints for contacts, properties, and other resources
- Scoped to current website for multi-tenant isolation
- RESTful CRUD operations

**Push Notification Value**:
- Alert API consumers of changes via webhooks or WebSocket events
- Rate-limiting notifications
- API key/authentication alerts
- Integration status notifications

**Integration Points**:
```
File: /app/controllers/pwb/api/v1/contacts_controller.rb
File: /app/controllers/pwb/api/v1/properties_controller.rb
```

### 6. Async Task Processing
**Priority**: MEDIUM (Future-ready)
**Current State**:
- Application has `Pwb::ApplicationJob` base class
- No current async jobs detected
- Materialized view refresh is manual or via potential `RefreshPropertiesViewJob`

**Push Notification Value**:
- Async job status notifications
- Long-running operation completion alerts
- Import/export job notifications
- Batch processing updates

**Implementation Ready**: The foundation exists for ActiveJob integration

## Proposed Push Notification System Architecture

### Technology Stack
1. **Backend**: Rails ActionCable + Sidekiq (optional for reliability)
2. **Frontend**: Web push API + Service Workers
3. **Mobile**: Native push via FCM (Android) and APNs (iOS)
4. **Storage**: Database table for notification preferences and history

### Key Features to Implement
1. **Notification Preferences**: User controls for notification types and frequency
2. **Multi-Tenant Isolation**: Notifications scoped to website/tenant
3. **Delivery Channels**: 
   - In-app (browser notifications)
   - Push notifications (mobile)
   - Email (existing system)
   - Webhook (for external integrations)
4. **Notification Queuing**: Handle delivery failures gracefully
5. **Audit Trail**: Track notification sent/read status

## Implementation Priority Map

### Phase 1 (Quick Wins)
1. Inquiry/Message Notifications - HIGH VALUE, CLEAR TRIGGER POINTS
2. Admin Dashboard Push - MEDIUM VALUE, EASY TO IMPLEMENT
3. User Registration Alerts - MEDIUM VALUE, EXISTING AUDIT LOG DATA

### Phase 2 (Property Management)
1. Property Listing Activation - HIGH VALUE, CLEAR CALLBACKS
2. Availability Updates - MEDIUM VALUE, AGENT-FOCUSED
3. Price Change Notifications - MEDIUM VALUE, MARKET-FOCUSED

### Phase 3 (Security & Advanced)
1. Account Security Alerts - MEDIUM VALUE, PROTECTION-FOCUSED
2. Suspicious Activity Warnings - HIGH VALUE, SECURITY-FOCUSED
3. Webhook Integrations - MEDIUM VALUE, INTEGRATION-FOCUSED

## Database Schema Considerations

Would require new tables:
- `pwb_push_notification_subscriptions` - Store device tokens and subscriptions
- `pwb_push_notifications` - Notification history and delivery status
- `pwb_notification_preferences` - User preferences for notification types
- `pwb_notification_templates` - Reusable notification content

## Code Examples for Integration Points

### Inquiry Notification (contact_us_controller.rb, line 92)
```ruby
# Current
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now

# With Push Notifications
def notify_inquiry(contact, enquiry)
  # Send email (existing)
  EnquiryMailer.general_enquiry_targeting_agency(contact, enquiry).deliver_later
  
  # Send push notification (new)
  Pwb::PushNotificationService.notify(
    website: @current_website,
    notification_type: :inquiry_received,
    title: "New Inquiry",
    body: "From #{contact.first_name}: #{enquiry.title}",
    data: { message_id: enquiry.id, contact_id: contact.id }
  )
end
```

### Property Listing Activation (rental_listing.rb, line 43)
```ruby
# Existing callback
after_save :ensure_active_listing_visible, if: :saved_change_to_active?

# Enhanced with notifications
def notify_activation
  Pwb::PushNotificationService.notify(
    website: realty_asset.website,
    notification_type: :property_activated,
    title: "Listing Active: #{realty_asset.reference}",
    body: "Your property is now live",
    data: { property_id: id, listing_id: id }
  )
end
```

### User Registration (user.rb, line 33)
```ruby
# Existing callback
after_create :log_registration

# Enhanced callback
after_create :send_registration_notification

def send_registration_notification
  Pwb::PushNotificationService.notify(
    user: self,
    notification_type: :registration_welcome,
    title: "Welcome!",
    body: "Thank you for registering"
  )
end
```

## Tenant Isolation Considerations

All push notifications must respect tenant boundaries:

1. **User Scope**: Notifications only to users with access to that tenant
2. **Admin Notifications**: Filtered by admin roles within website membership
3. **Cross-Tenant User Handling**: Users with memberships in multiple websites can receive updates for each
4. **Subscription Filtering**: Push subscriptions associated with website+user combination

## Security Considerations

1. **Authentication**: Validate subscription tokens and device ownership
2. **Authorization**: Only send notifications to authorized users
3. **Rate Limiting**: Prevent notification spam
4. **Data Privacy**: Don't expose sensitive data in push notification payloads
5. **PII Handling**: Be careful with personal information in push titles/bodies

## Conclusion

PropertyWebBuilder has excellent infrastructure for implementing push notifications. The priority areas are:

1. **Inquiry/Message Notifications** - Direct business value
2. **Property Listing Updates** - Critical for agents
3. **Account Security Alerts** - Protection against fraud
4. **Admin Dashboard Updates** - Operational efficiency

The multi-tenant architecture is well-designed for isolated notification delivery, and the existing audit logging system demonstrates sophisticated event tracking that can be leveraged for notifications.
