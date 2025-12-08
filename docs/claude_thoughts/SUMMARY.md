# Push Notifications - Exploration Summary

## Overview

I've completed a comprehensive analysis of the PropertyWebBuilder codebase to identify where push notifications could add significant value. The codebase is well-architected with strong multi-tenancy support, existing email notification systems, and rich audit logging that makes it an ideal candidate for push notifications.

## Documents Created

1. **push_notifications_analysis.md** - Comprehensive technical analysis
2. **push_notifications_opportunities.md** - Quick reference with implementation priority
3. **code_locations_reference.md** - Detailed code location map for developers

## Key Findings

### Highest Value Opportunities

#### 1. Inquiry/Message Notifications (Priority: HIGH)
- **Why**: Direct business impact - alerts agents to incoming inquiries immediately
- **Current System**: Email via `EnquiryMailer.general_enquiry_targeting_agency`
- **Enhancement**: Add push notifications to accelerate response time
- **Code**: `app/controllers/pwb/contact_us_controller.rb:92`
- **Impact**: Improved conversion rate, faster customer engagement

#### 2. Property Listing Changes (Priority: HIGH)
- **Why**: Critical for property management workflow
- **Current System**: Model callbacks with materialized view refresh
- **Enhancement**: Notify when listings are activated/deactivated/archived
- **Code**: 
  - `app/models/pwb/rental_listing.rb:42-43`
  - `app/models/pwb/sale_listing.rb:39-40`
- **Impact**: Agents aware of inventory changes in real-time

#### 3. Security & Account Events (Priority: MEDIUM-HIGH)
- **Why**: Protect accounts from unauthorized access
- **Current System**: Rich audit logging in `AuthAuditLog`
- **Enhancement**: Push notifications for failed logins, account locks, suspicious activity
- **Code**: `app/models/pwb/auth_audit_log.rb` (11 event types available)
- **Impact**: Early warning system for account security

#### 4. User Registration & Welcome (Priority: MEDIUM)
- **Why**: Improve onboarding experience
- **Current System**: Devise handles email confirmation
- **Enhancement**: Welcome push notification with quick links
- **Code**: `app/models/pwb/user.rb:33` (after_create hook)
- **Impact**: Better user experience, increased platform engagement

#### 5. Admin Dashboard Summaries (Priority: MEDIUM)
- **Why**: Keep admins informed of activity
- **Current System**: Dashboard with recent activity feeds
- **Enhancement**: Real-time push for activity thresholds
- **Code**: `app/controllers/site_admin/dashboard_controller.rb:8-26`
- **Impact**: Operational awareness, faster decision-making

### Existing Infrastructure to Leverage

1. **Email System** - `Pwb::EnquiryMailer` and `Pwb::ApplicationMailer`
   - Can transition to async delivery with `deliver_later`
   - Multi-channel approach (email + push)

2. **Audit Logging** - `Pwb::AuthAuditLog`
   - 11 event types already tracked
   - Rich context: IP, user_agent, request_path
   - Scoped queries ready for notification delivery

3. **Multi-Tenancy** - `website_id` foreign keys everywhere
   - Strong tenant isolation already in place
   - `Pwb::Current.website` context available
   - Permission model ready: owner, admin, member roles

4. **ActiveJob Base** - `Pwb::ApplicationJob`
   - Foundation for async delivery ready
   - Can support Sidekiq or other backends

## Architecture Summary

### Multi-Tenant Notification Flow
```
User creates inquiry
    ↓
ContactUsController captures form
    ↓
Create Contact + Message records (scoped to website_id)
    ↓
Trigger notifications (split by channel)
    ├─ Email: EnquiryMailer.deliver_later
    └─ Push: SendPushNotificationJob.perform_later
    ↓
Notification queued (respects user preferences)
    ↓
Delivered to authorized users (admin_for? check)
    ↓
Multi-tenant isolation maintained throughout
```

### Required New Components

**Models**:
- `PushNotification` - Notification record and history
- `PushNotificationSubscription` - Device tokens per user/website
- `NotificationPreference` - User preference settings

**Services**:
- `PushNotificationService` - Core logic for deciding who to notify
- `PushNotificationDelivery` - Sending to device (Web Push API, APNs, FCM)

**Jobs**:
- `SendPushNotificationJob` - Async delivery handler

**Database**:
- `pwb_push_notification_subscriptions` table
- `pwb_push_notifications` table (history + delivery status)
- `pwb_notification_preferences` table

## Implementation Roadmap

### Phase 1: Foundation (2-3 weeks)
- [ ] Create database schema for subscriptions and preferences
- [ ] Build `PushNotification` models
- [ ] Implement subscription management API
- [ ] Create `PushNotificationService` core logic
- [ ] Setup Web Push API integration

### Phase 2: Inquiry Notifications (1-2 weeks)
- [ ] Integrate with contact form submission
- [ ] Create notification templates
- [ ] Add admin dashboard notifications
- [ ] Test multi-tenant isolation

### Phase 3: Property & User Events (2 weeks)
- [ ] Add listing activation notifications
- [ ] Implement user registration welcome
- [ ] Security event notifications

### Phase 4: Advanced Features (2+ weeks)
- [ ] Mobile app integration (FCM, APNs)
- [ ] Webhook support for external integrations
- [ ] Notification preferences UI
- [ ] Analytics and delivery reports

## Code Integration Checklist

For each notification type, integrate at:

**Inquiry Notifications**:
- [ ] Modify `contact_us_controller.rb:92` to add push
- [ ] Create job: `SendInquiryNotificationJob`
- [ ] Create template for notification content

**Listing Activations**:
- [ ] Add callback to `rental_listing.rb`
- [ ] Add callback to `sale_listing.rb`
- [ ] Create job: `SendListingNotificationJob`

**User Registration**:
- [ ] Add callback to `user.rb`
- [ ] Create job: `SendWelcomeNotificationJob`

**Security Events**:
- [ ] Enhance `auth_audit_log.rb` with notification hook
- [ ] Create job: `SendSecurityAlertJob`

## Security & Compliance

### Multi-Tenant Isolation
- All queries must include `website_id` scope
- User permissions verified before sending (admin_for? check)
- Subscription tokens tied to website+user combination

### Data Privacy
- Never expose PII in notification title/body
- Use IDs and generic text in preview
- Full data only on click-through
- GDPR-compliant opt-in/out

### Rate Limiting
- Throttle rapid notifications from same source
- Daily digest options for high-volume scenarios
- User-configurable notification frequency

## Success Metrics

### Engagement
- Notification click-through rate
- Response time to inquiries
- User opt-in percentage

### Business
- Inquiry-to-lead conversion rate improvement
- Agent response time reduction
- Platform retention rate
- Support ticket reduction ("why didn't I get notified?")

### Technical
- Notification delivery success rate (>99%)
- Latency (push within <5 seconds of trigger)
- Error rate (<1%)

## Risk Mitigation

1. **Over-notification**: Implement preference controls and digest mode
2. **Delivery Failures**: Queue with retry logic and fallback to email
3. **Privacy Concerns**: Clear privacy policy and easy opt-out
4. **Performance**: Async delivery via background jobs
5. **Multi-tenant Bugs**: Comprehensive test coverage with tenant isolation tests

## Next Steps

1. **Read Documentation**: Start with `push_notifications_analysis.md` for full context
2. **Review Code**: Use `code_locations_reference.md` to navigate codebase
3. **Check Opportunities**: Reference `push_notifications_opportunities.md` for quick implementation guides
4. **Start with Phase 1**: Build database schema and models
5. **Test with Inquiries**: Use inquiry notifications as first feature (most direct value)

## Files Created

All documentation placed in `/docs/claude_thoughts/` per project guidelines:

```
docs/claude_thoughts/
├── push_notifications_analysis.md (14KB) - Comprehensive analysis
├── push_notifications_opportunities.md (12KB) - Quick reference
├── code_locations_reference.md (16KB) - Code navigation map
└── SUMMARY.md (this file)
```

## Questions for Stakeholders

1. What delivery channels are most important? (Web push, mobile, email, webhook?)
2. Should notifications be real-time or support digest mode?
3. What's the target mobile app platform? (React Native, native iOS/Android?)
4. Any existing analytics system to track notification performance?
5. Are there notification rate-limiting requirements?

---

## Conclusion

PropertyWebBuilder has excellent potential for push notifications. The codebase is well-structured with:
- Clear multi-tenant architecture ✓
- Existing email infrastructure ✓
- Rich audit logging system ✓
- Strong permission model ✓
- Clear integration points ✓

**Recommended approach**: Start with inquiry notifications (highest ROI), validate the infrastructure with real users, then expand to other notification types.

The 3-phase approach can deliver core functionality in 4-5 weeks, with full feature parity in 8-10 weeks total.

