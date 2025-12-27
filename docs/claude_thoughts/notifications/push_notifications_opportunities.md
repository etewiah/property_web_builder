# Push Notification Opportunities - Quick Reference

## High-Value Notification Triggers

### 1. INQUIRY RECEIVED (Priority: HIGH)
**Business Value**: Real-time agent engagement
```
Trigger: Contact form submission
Models: Contact, Message
Email Already: Yes (EnquiryMailer)
File: app/controllers/pwb/contact_us_controller.rb:92
Notify: Agency admins, assigned agents

Notification:
- "New Inquiry: {subject}"
- "From {contact_name}: {preview}"
```

### 2. PROPERTY ACTIVATED (Priority: HIGH)
**Business Value**: Inventory visibility
```
Trigger: Listing activation
Models: RentalListing, SaleListing
Email Already: No
Files: 
  - app/models/pwb/rental_listing.rb:42-43
  - app/models/pwb/sale_listing.rb:39-40
Notify: Property managers, assigned agents

Notification:
- "Listing Live: {property_reference}"
- "{bedrooms}bd {bathrooms}ba - {price}"
```

### 3. PROPERTY DEACTIVATED (Priority: MEDIUM)
**Business Value**: Inventory updates
```
Trigger: Listing deactivation/archive
Models: RentalListing, SaleListing
File: app/models/pwb/rental_listing.rb:66-68
Notify: Property managers, assigned agents

Notification:
- "Listing Inactive: {property_reference}"
- "No longer available"
```

### 4. USER REGISTRATION (Priority: MEDIUM)
**Business Value**: Onboarding engagement
```
Trigger: New user signup via Devise
Models: User, AuthAuditLog
Email Already: Devise sends confirmation
File: app/models/pwb/user.rb:33
Notify: New user, website admins

Notification:
- "Welcome to {website_name}!"
- "Complete your profile to get started"
```

### 5. ACCOUNT SECURITY EVENT (Priority: MEDIUM-HIGH)
**Business Value**: Account protection
```
Trigger: Multiple login failures, account locked
Models: User, AuthAuditLog
Email Already: No (opportunity)
File: app/models/pwb/auth_audit_log.rb
Notify: User with alerts, website admins with summaries

Notifications:
- "Failed login attempt from {ip}"
- "Your account has been locked for security"
- "Suspicious activity detected on your account"
```

### 6. MESSAGE IN INBOX (Priority: MEDIUM)
**Business Value**: Real-time communication
```
Trigger: Message/inquiry created
Models: Message, Contact
Email Already: Yes
File: app/models/pwb/message.rb
Notify: Assigned contact person

Notification:
- "New message from {sender}"
- "{message_preview}..."
```

### 7. ADMIN ACTIVITY THRESHOLD (Priority: MEDIUM)
**Business Value**: Operational awareness
```
Trigger: Configurable thresholds (5+ inquiries, etc)
Models: Message, Contact (dashboard aggregates)
Email Already: No
File: app/controllers/site_admin/dashboard_controller.rb:8-26
Notify: Website admins

Notifications:
- "10 new inquiries received today"
- "Dashboard Summary: 5 properties, 3 messages"
```

### 8. PASSWORD RESET (Priority: LOW-MEDIUM)
**Business Value**: Account recovery
```
Trigger: Password reset requested
Models: User, AuthAuditLog
Email Already: Devise sends link
File: app/models/pwb/user.rb
Notify: User

Notification:
- "Password reset link sent to your email"
- "This link expires in 24 hours"
```

---

## Existing Infrastructure to Leverage

### Email System (Ready to Enhance)
- `Pwb::ApplicationMailer` - Base class
- `Pwb::EnquiryMailer` - Inquiry notifications
- Already using `deliver_now` (can switch to `deliver_later`)
- Multi-tenant aware

### Audit Logging (Rich Event Data)
- `Pwb::AuthAuditLog` - 11 event types
- User, email, IP, user_agent, website scoped
- Existing scopes for common queries
- Security event classification

### Multi-Tenancy (Isolation Ready)
- `website_id` foreign keys
- `Pwb::Current.website` context
- `user_memberships` for multi-website access
- Tenant-scoped models (`PwbTenant::*`)

### Role-Based Access (Permission Ready)
- User roles: owner, admin, member
- `admin_for?(website)` method
- `role_for(website)` method
- `accessible_websites` scope

---

## Implementation Checklist

### Database
- [ ] Create `pwb_push_notification_subscriptions` table
- [ ] Create `pwb_push_notifications` table (history)
- [ ] Create `pwb_notification_preferences` table
- [ ] Add indexes on (website_id, user_id)

### Models
- [ ] `Pwb::PushNotification` - Notification record
- [ ] `Pwb::PushNotificationSubscription` - Device token storage
- [ ] `Pwb::NotificationPreference` - User preferences
- [ ] Model callbacks for triggers

### Services
- [ ] `Pwb::PushNotificationService` - Main service
- [ ] `Pwb::PushNotificationDelivery` - Delivery handler
- [ ] `Pwb::NotificationPermissionChecker` - Auth check

### Controllers
- [ ] API endpoints for subscriptions
- [ ] Preference management UI
- [ ] Notification history view

### Jobs
- [ ] `Pwb::SendPushNotificationJob` - Async delivery
- [ ] `Pwb::CleanupNotificationJob` - Pruning old records

### Frontend
- [ ] Service Worker registration
- [ ] Push event handling
- [ ] Notification click handling
- [ ] Subscription management UI

---

## Risk Mitigation

### Multi-Tenant Isolation
```ruby
# Always include website scope
notifications = Pwb::PushNotification
  .where(website_id: current_website.id)
  .where(user_id: current_user.id)
```

### Permission Verification
```ruby
# Check user has role before sending
if user.admin_for?(website)
  notify_admin(user, notification)
end
```

### Rate Limiting
```ruby
# Prevent notification spam
user.last_notification_sent_at > 1.minute.ago ? skip : send
```

### Data Privacy
```ruby
# Don't expose sensitive data in notification title/body
notification.title = "New Inquiry"  # Safe
notification.title = "Inquiry from #{contact.email}"  # UNSAFE
```

---

## Quick Start: Inquiry Notifications

**File to modify**: `/app/controllers/pwb/contact_us_controller.rb`

**Current code (line 92)**:
```ruby
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_now
```

**Enhanced code**:
```ruby
# Send email (async for speed)
EnquiryMailer.general_enquiry_targeting_agency(@contact, @enquiry).deliver_later

# Send push notification
if @current_website.push_notifications_enabled?
  Pwb::SendPushNotificationJob.perform_later(
    website_id: @current_website.id,
    notification_type: :inquiry_received,
    inquiry_id: @enquiry.id
  )
end
```

**Create notification service**:
```ruby
# app/services/pwb/push_notification_service.rb
module Pwb
  class PushNotificationService
    def self.notify_inquiry(inquiry)
      website = inquiry.website
      contact = inquiry.contact
      
      # Get admins for this website
      admins = website.users.joins(:user_memberships)
        .where(pwb_user_memberships: { role: ['owner', 'admin'] })
      
      # Send to each admin with active subscriptions
      admins.each do |admin|
        subscriptions = admin.push_notification_subscriptions
          .where(website_id: website.id)
        
        subscriptions.each do |subscription|
          send_to_device(
            subscription,
            title: "New Inquiry",
            body: "From #{contact.first_name}: #{inquiry.title[0..50]}...",
            data: { inquiry_id: inquiry.id }
          )
        end
      end
    end
  end
end
```

---

## Measuring Success

### Key Metrics
1. **Notification Engagement**: % of notifications clicked
2. **Response Time**: Time to respond to notifications
3. **Opt-in Rate**: % of users enabling notifications
4. **Unsubscribe Rate**: % of users disabling notifications
5. **Delivery Success Rate**: % of successful deliveries

### Business Outcomes
1. **Agent Responsiveness**: Faster inquiry responses
2. **Conversion Rate**: Higher inquiry-to-lead conversion
3. **User Retention**: Better engagement with platform
4. **Support Tickets**: Reduction in "why didn't I get notified" tickets

