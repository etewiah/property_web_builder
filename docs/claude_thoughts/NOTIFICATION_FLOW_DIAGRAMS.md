# Push Notification Flow Diagrams

## Current State: Inquiry Notification Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  Website Visitor                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
        ┌────────────────────────────────────┐
        │  Contact Form Submission           │
        │  (pwb/contact_us#contact_us_ajax)  │
        └────────────────┬───────────────────┘
                         │
        ┌────────────────▼───────────────────┐
        │  Create Contact Record             │
        │  (find_or_initialize_by email)     │
        └────────────────┬───────────────────┘
                         │
        ┌────────────────▼───────────────────┐
        │  Create Message Record             │
        │  (scope: website_id)               │
        └────────────────┬───────────────────┘
                         │
        ┌────────────────▼───────────────────────────────────────┐
        │  Send Email (SYNCHRONOUS - CURRENT)                   │
        │  EnquiryMailer.general_enquiry_targeting_agency        │
        │  .deliver_now                                          │
        │  Recipient: @current_agency.email_for_general_contact │
        └────────────────┬───────────────────────────────────────┘
                         │
        ┌────────────────▼───────────────────┐
        │  Render Success Response           │
        │  (contact_us_success)              │
        └────────────────────────────────────┘


                  ✗ NO PUSH NOTIFICATIONS YET
                  (Opportunity: Add here!)
```

## Proposed: Enhanced Inquiry Notification Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  Website Visitor                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
        ┌────────────────────────────────────┐
        │  Contact Form Submission           │
        │  (pwb/contact_us#contact_us_ajax)  │
        └────────────────┬───────────────────┘
                         │
        ┌────────────────▼───────────────────┐
        │  Create Contact Record             │
        │  (find_or_initialize_by email)     │
        └────────────────┬───────────────────┘
                         │
        ┌────────────────▼───────────────────┐
        │  Create Message Record             │
        │  (scope: website_id)               │
        └────────────────┬───────────────────┘
                         │
                ┌────────┴────────┐
                │                 │
                ▼                 ▼
    ┌──────────────────┐  ┌──────────────────────────┐
    │  Send Email      │  │  Queue Push Jobs         │
    │  (ASYNC now)     │  │  (ASYNC)                 │
    │  deliver_later   │  │  SendPushNotificationJob │
    │                  │  │  .perform_later          │
    └────────┬─────────┘  └──────────┬───────────────┘
             │                       │
             │                       ▼
             │           ┌───────────────────────┐
             │           │  Find Target Users    │
             │           │  (admin_for? website) │
             │           └───────────┬───────────┘
             │                       │
             │                       ▼
             │           ┌──────────────────────┐
             │           │  Get Subscriptions   │
             │           │  (devices per user)  │
             │           └───────────┬──────────┘
             │                       │
             │                       ▼
             │           ┌──────────────────────┐
             │           │  Send via Channels   │
             │           │  • Web Push API      │
             │           │  • FCM (Android)     │
             │           │  • APNs (iOS)        │
             │           └───────────┬──────────┘
             │                       │
             └───────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────────────┐
            │  Render Success Response       │
            │  (contact_us_success)          │
            └────────────────────────────────┘


                  ✓ NEW: Push notifications sent!
                  (Admin gets immediate alert on device)
```

## Current State: Property Listing Flow

```
┌────────────────────────────────────────────────────┐
│  Admin Updates Property Listing                    │
│  (site_admin/props/rental_listings#update)         │
└───────────────────────┬────────────────────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │  Update RentalListing │
            │  .activate!           │
            │  active: true         │
            └───────────┬───────────┘
                        │
        ┌───────────────┴──────────────┐
        │  Callbacks Fire              │
        ▼                              ▼
    ┌──────────────────┐    ┌──────────────────────┐
    │ before_save:     │    │ after_save:          │
    │ deactivate_      │    │ ensure_active_       │
    │ other_listings   │    │ listing_visible      │
    └──────────────────┘    └──────────────────────┘
                                       │
                                       ▼
                        ┌──────────────────────────┐
                        │ after_commit:            │
                        │ refresh_properties_view  │
                        │ (materialized view)      │
                        └──────────────────────────┘


                  ✗ NO NOTIFICATIONS YET
                  (Opportunity: Add here!)
```

## Proposed: Enhanced Property Listing Flow

```
┌────────────────────────────────────────────────────┐
│  Admin Updates Property Listing                    │
│  (site_admin/props/rental_listings#update)         │
└───────────────────────┬────────────────────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │  Update RentalListing │
            │  .activate!           │
            │  active: true         │
            └───────────┬───────────┘
                        │
        ┌───────────────┴───────────────────┐
        │  Callbacks Fire                   │
        ▼                                   ▼
    ┌──────────────────┐    ┌────────────────────────┐
    │ before_save:     │    │ after_save:            │
    │ deactivate_      │    │ ensure_active_         │
    │ other_listings   │    │ listing_visible        │
    └──────────────────┘    └────────────┬───────────┘
                                         │
                 ┌───────────────────────┼─────────────────────┐
                 │                       │                     │
                 ▼                       ▼                     ▼
    ┌─────────────────────┐ ┌──────────────────────┐ ┌────────────────────┐
    │ after_commit:       │ │ NEW CALLBACK:        │ │ Materialized View  │
    │ refresh_properties_ │ │ notify_activation    │ │ Refresh            │
    │ view (materialized) │ │                      │ │ (ListedProperty)   │
    │                     │ │ SendListingNotifJob  │ │                    │
    │                     │ │ .perform_later       │ │                    │
    └─────────────────────┘ └──────────┬───────────┘ └────────────────────┘
                                        │
                                        ▼
                            ┌──────────────────────────┐
                            │  Find Admins for Site    │
                            │  (admin_for? check)      │
                            └──────────┬───────────────┘
                                       │
                                       ▼
                            ┌──────────────────────────┐
                            │  Get Subscriptions       │
                            │  (per admin, per site)   │
                            └──────────┬───────────────┘
                                       │
                                       ▼
                            ┌──────────────────────────┐
                            │  Send Push               │
                            │  "Listing Live: ABC123"  │
                            │  "5bd 3ba - $2.5M"       │
                            └──────────────────────────┘


                  ✓ NEW: Property managers notified!
```

## Multi-Tenant Isolation Pattern

```
                    ┌─────────────────────┐
                    │  Website A          │
                    │  (tenant_id: 1)     │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            ▼                  ▼                  ▼
        ┌────────┐        ┌────────┐        ┌────────┐
        │ Contact│        │Messages│        │Listings│
        │ id: 1  │        │id: 1-5 │        │id: 1-3 │
        │w_id: 1 │        │w_id: 1 │        │w_id: 1 │
        └────────┘        └────────┘        └────────┘


                    ┌─────────────────────┐
                    │  Website B          │
                    │  (tenant_id: 2)     │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            ▼                  ▼                  ▼
        ┌────────┐        ┌────────┐        ┌────────┐
        │ Contact│        │Messages│        │Listings│
        │ id: 2  │        │id: 6-8 │        │id: 4-5 │
        │w_id: 2 │        │w_id: 2 │        │w_id: 2 │
        └────────┘        └────────┘        └────────┘


              Notification Routing (Query Scoping)

    ┌──────────────────────────────────────┐
    │ Inquiry Created (message_id: 3)      │
    │ website_id = 1                       │
    └───────────────┬──────────────────────┘
                    │
                    ▼
        ┌──────────────────────────┐
        │ Query: Get Admins        │
        │ WHERE website_id = 1     │
        │ AND admin_for?(1)        │
        └───────────┬──────────────┘
                    │
                    ▼ (Found: Admin1, Admin2)
        ┌──────────────────────────┐
        │ Get Subscriptions        │
        │ WHERE user_id IN (...)   │
        │ AND website_id = 1       │
        └───────────┬──────────────┘
                    │
                    ▼
        ┌──────────────────────────┐
        │ Send Push to Admin1       │
        │ Send Push to Admin2       │
        │ (Website A only!)        │
        └──────────────────────────┘
```

## Notification State Machine

```
┌──────────────────────────────────────────────────────────┐
│                  Notification States                     │
└──────────────────────────────────────────────────────────┘

            ┌────────────────┐
            │   QUEUED       │
            │   (in job)     │
            └────────┬───────┘
                     │
                     ▼
            ┌────────────────┐
            │  SENDING       │
            │  (in flight)   │
            └────────┬───────┘
                     │
            ┌────────┴────────┐
            │                 │
            ▼                 ▼
    ┌──────────────┐  ┌──────────────┐
    │ DELIVERED    │  │ FAILED       │
    │ (received)   │  │ (error)      │
    └──────┬───────┘  └──────┬───────┘
           │                 │
           ▼                 ▼
    ┌──────────────┐  ┌──────────────┐
    │ READ         │  │ RETRY        │
    │ (clicked)    │  │ (attempt n+1)│
    └──────────────┘  └──────┬───────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
            ┌──────────────┐  ┌──────────────┐
            │ DELIVERED    │  │ ABANDONED    │
            │ (after retry)│  │ (max retries)│
            └──────────────┘  └──────────────┘
```

## Database Model Relationships

```
User
  ├─ has_many: push_notification_subscriptions
  │  ├─ device_token (FCM, APNs, Web)
  │  ├─ user_agent
  │  ├─ website_id (multi-tenant scope)
  │  └─ subscribed_at
  │
  └─ has_many: notification_preferences
     ├─ notification_type (inquiry, listing, security, etc)
     ├─ enabled (boolean)
     ├─ frequency (real-time, daily, weekly, manual)
     └─ channels (push, email, webhook)

Message / Inquiry
  ├─ belongs_to: website
  ├─ has_many: push_notifications
  │  ├─ notification_type: inquiry_received
  │  ├─ status: queued → sending → delivered/failed
  │  ├─ delivered_at
  │  └─ read_at
  └─ sent_to_users (through push_notifications)

RentalListing / SaleListing
  ├─ belongs_to: website
  ├─ has_many: push_notifications
  │  ├─ notification_type: listing_activated
  │  ├─ status: queued → delivered
  │  └─ recipients (admins for that website)
  └─ triggers notify_activation callback

PushNotification (History Log)
  ├─ notification_type (enum)
  ├─ user_id
  ├─ website_id
  ├─ notifiable_id / notifiable_type (polymorphic)
  ├─ status (queued, sending, delivered, failed, read)
  ├─ delivery_channels (json array)
  ├─ created_at
  ├─ delivered_at
  ├─ read_at
  └─ error_message (if failed)
```

## Async Job Flow

```
┌──────────────────────────────┐
│  Inquiry Created             │
│  Message#create callback     │
│  OR                          │
│  contact_us_controller:92    │
└────────────┬─────────────────┘
             │
             ▼
    ┌─────────────────────────┐
    │  SendPushNotificationJob│
    │  .perform_later         │
    │  (inquiry_id: 123)      │
    └────────────┬────────────┘
                 │
                 ▼ (Sidekiq Queue)
    ┌─────────────────────────┐
    │  Background Worker      │
    │  DequeueAndProcess      │
    └────────────┬────────────┘
                 │
    ┌────────────┴───────────────┐
    │                            │
    ▼                            ▼
┌───────────────┐     ┌──────────────────┐
│ Load inquiry  │     │ Find admins      │
│ Find website  │     │ Check perms      │
│ Get templates │     │ Find devices     │
└───────────────┘     └──────────────────┘
    │                            │
    └────────────┬───────────────┘
                 │
                 ▼
    ┌────────────────────────┐
    │ For each subscription: │
    │  Send to channel:      │
    │  • Web Push API        │
    │  • Firebase Cloud      │
    │    Messaging (FCM)     │
    │  • Apple Push (APNs)   │
    └────────────┬───────────┘
                 │
                 ▼
    ┌────────────────────────┐
    │ Log result in DB       │
    │ Mark delivered/failed  │
    └────────────────────────┘
```

## User Preference Controls

```
User Settings
    │
    ├─ Notifications Enabled? (global toggle)
    │   └─ Yes → Continue
    │   └─ No → Skip all notifications
    │
    ├─ For each notification type:
    │   │
    │   ├─ Inquiry Notifications
    │   │   ├─ Enabled? Yes/No
    │   │   ├─ Frequency: Real-time / Daily Digest / Weekly
    │   │   └─ Channels: Push / Email / Webhook
    │   │
    │   ├─ Listing Notifications
    │   │   ├─ Enabled? Yes/No
    │   │   ├─ Frequency: Real-time / Weekly
    │   │   └─ Channels: Push / Email
    │   │
    │   ├─ Security Alerts
    │   │   ├─ Enabled? Yes/No
    │   │   ├─ Always Real-time
    │   │   └─ Channels: Push / Email
    │   │
    │   └─ Admin Summaries
    │       ├─ Enabled? Yes/No
    │       ├─ Frequency: Daily / Weekly
    │       └─ Channels: Email / Webhook
    │
    └─ Manage Devices
        └─ List active subscriptions by device type
            (Browser, iOS App, Android App)
```

---

These diagrams illustrate the current state and proposed enhancements for push notifications throughout PropertyWebBuilder's key workflows.

