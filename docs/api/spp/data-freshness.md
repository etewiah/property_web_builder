# SPP Data Freshness Strategy

**Status:** Phase 1 Implemented (cache headers), Phase 2 planned (webhooks)
**Related:** [SPP–PWB Integration](./README.md) | [SppListing Model](./spp-listing-model.md)

---

## Summary

SPP fetches property data from PWB's API. When property data changes on PWB (price, photos, description), SPP needs to reflect those changes. This document evaluates strategies and recommends an approach.

## Current State

### What Triggers Data Changes

Property data changes when an agent:
- Updates price, description, or other listing fields
- Adds, removes, or reorders photos
- Publishes or unpublishes a listing
- Archives or reserves a listing

### Existing Callback Infrastructure

PWB already has `after_commit` callbacks that fire on listing changes:

**`NtfyListingNotifications` concern** (`app/models/concerns/ntfy_listing_notifications.rb`):
- Fires on: listing activated, archived, visibility changed
- Enqueues `NtfyNotificationJob` to send push notifications

**`RefreshesPropertiesView` concern** (`app/models/concerns/refreshes_properties_view.rb`):
- Fires on: create, update, destroy of `RealtyAsset`, `SaleListing`, `RentalListing`
- Enqueues `RefreshPropertiesViewJob` to update the materialized view

These callbacks are the natural hook points for notifying SPP.

### Current API Caching

`ApiPublic::V1::BaseController` sets `expires_in 1.hour, public: true` on all responses (reduced from 5 hours as part of Phase 1).

## Strategy Evaluation

### Option 1: Cache Headers (Passive)

**How:** SPP respects the `Cache-Control` and `Last-Modified` headers from PWB's API. Astro's server-side data fetching can cache responses and re-validate with conditional GET (`If-Modified-Since`).

**Staleness:** Up to 1 hour (current `expires_in` value after Phase 1 reduction).

**Pros:**
- Zero implementation on PWB — already works
- No new infrastructure
- Standard HTTP semantics

**Cons:**
- 5-hour delay (or whatever the cache TTL is)
- No way to force an immediate refresh
- SPP must poll to discover changes

### Option 2: Webhooks (Active Push)

**How:** When property data changes, PWB sends an HTTP POST to SPP with the property ID and change type. SPP invalidates its cache and re-fetches the data.

**Implementation on PWB:**

1. **Store webhook URL per tenant** in `client_theme_config`:
   ```json
   {
     "spp_webhook_url": "https://spp.example.com/api/webhooks/pwb",
     "spp_webhook_secret": "whsec_..."
   }
   ```

2. **Create a webhook delivery job** that extends the existing callback infrastructure:

   ```ruby
   # app/jobs/spp_webhook_job.rb
   class SppWebhookJob < ApplicationJob
     queue_as :webhooks
     retry_on StandardError, wait: :polynomially_longer, attempts: 5

     def perform(website_id, event_type, payload)
       website = Pwb::Website.find(website_id)
       webhook_url = website.client_theme_config&.dig('spp_webhook_url')
       secret = website.client_theme_config&.dig('spp_webhook_secret')
       return unless webhook_url.present?

       body = {
         event: event_type,
         timestamp: Time.current.iso8601,
         data: payload
       }.to_json

       signature = OpenSSL::HMAC.hexdigest('SHA256', secret, body) if secret

       response = HTTP.timeout(10).headers(
         'Content-Type' => 'application/json',
         'X-PWB-Signature' => signature
       ).post(webhook_url, body: body)

       unless response.status.success?
         raise "Webhook delivery failed: #{response.status}"
       end
     end
   end
   ```

3. **Hook into existing callbacks** — add an `after_commit` in the listing models or extend `NtfyListingNotifications`:

   ```ruby
   after_commit :notify_spp_webhook, on: [:create, :update]

   def notify_spp_webhook
     SppWebhookJob.perform_later(
       website_id,
       'property.updated',
       { property_id: realty_asset_id, listing_type: self.class.name }
     )
   end
   ```

**Webhook payload:**
```json
{
  "event": "property.updated",
  "timestamp": "2026-02-12T10:30:00Z",
  "data": {
    "property_id": "abc-123-uuid",
    "listing_type": "Pwb::SaleListing"
  }
}
```

**SPP receives this and:**
1. Verifies the HMAC signature
2. Re-fetches the property data from `api_public/v1/properties/:id`
3. Updates its cache or triggers a page rebuild

**Pros:**
- Near-instant updates (seconds, not hours)
- PWB controls the notification — SPP doesn't need to poll
- Extends existing callback infrastructure naturally

**Cons:**
- New infrastructure (webhook job, configuration, signature verification)
- Need retry logic, failure handling, delivery logging
- SPP needs a webhook receiver endpoint

### Option 3: Build Hook (Static SPP)

**How:** If SPP generates static pages (Astro static builds), PWB triggers a rebuild by hitting a build hook URL (e.g., Vercel deploy hook, Cloudflare Pages build hook).

**Implementation:** Same as Option 2 but the webhook URL is a build service hook instead of an SPP endpoint:

```json
{
  "spp_build_hook_url": "https://api.vercel.com/v1/integrations/deploy/prj_xxx/dep_yyy"
}
```

**Pros:**
- Simple — just a POST to a URL, no payload verification needed
- Works with any static hosting provider

**Cons:**
- Full site rebuild for any single property change (slow, wasteful)
- Build hooks are typically rate-limited
- Delay depends on build time (could be minutes)
- Only works if SPP uses static generation (not SSR)

### Option 4: Hybrid (Recommended)

**Combine cache headers + webhooks:**

1. **Cache headers** provide the baseline — SPP always has reasonably fresh data (reduce TTL to 1 hour for property detail endpoints)
2. **Webhooks** provide real-time updates for important changes (price, visibility, photos)
3. **No build hooks** — assume SPP uses SSR (Astro server-side rendering) since it needs to support dynamic features like enquiry forms

**Implementation phases:**

| Phase | Strategy | Latency | Effort |
|-------|----------|---------|--------|
| Phase 1 (now) | Cache headers only | Up to 1 hour | Zero — already works |
| Phase 2 (when needed) | Add webhooks | Seconds | Moderate — new job, config |

## Recommended Approach: Phase 1 Now, Phase 2 Later

### Phase 1: Reduce Cache TTL (Done)

The `api_public` base controller cache TTL was reduced from 5 hours to 1 hour:

```ruby
# app/controllers/api_public/v1/base_controller.rb
expires_in 1.hour, public: true
```

SPP sees updates within an hour with no new infrastructure. Covered by 3 specs in `spec/requests/api_public/v1/cache_headers_spec.rb`.

### Phase 2: Add Webhooks (When Real-Time Matters)

Build the webhook system described in Option 2 when tenants report that 1-hour staleness is unacceptable. The callback hooks already exist — the work is creating the delivery job and adding configuration.

**Trigger events to support:**

| Event | Trigger | Data |
|-------|---------|------|
| `property.updated` | Listing fields changed | `{ property_id }` |
| `property.published` | Listing made visible | `{ property_id, liveUrl }` |
| `property.unpublished` | Listing hidden | `{ property_id }` |
| `property.photos_changed` | Photos added/removed/reordered | `{ property_id }` |
| `property.archived` | Listing archived | `{ property_id }` |

SPP can choose which events to act on. For most cases, `property.updated` as a catch-all is sufficient.

## Implementation Checklist

### Phase 1 (Done)
- [x] Reduced cache TTL on all `api_public` endpoints to 1 hour
- [x] `Vary` header set for `Accept-Language, X-Website-Slug` for proper edge caching
- [x] Conditional GET (`If-Modified-Since`) supported via `fresh_when` in base controller
- [ ] SPP: Use conditional GET headers to avoid re-downloading unchanged data

### Phase 2 (Later)
1. Add `spp_webhook_url` and `spp_webhook_secret` to `client_theme_config` schema
2. Create `SppWebhookJob` with HMAC signing and retry logic
3. Add `after_commit` callback to `SaleListing` and `RentalListing`
4. SPP: Create webhook receiver endpoint with signature verification
5. Add webhook delivery logging (success/failure, response code, latency)
6. Add monitoring for failed webhook deliveries

## Reference Files

| File | Relevance |
|------|-----------|
| `app/models/concerns/ntfy_listing_notifications.rb` | Existing after_commit callbacks for listing changes |
| `app/models/concerns/refreshes_properties_view.rb` | Existing after_commit for materialized view refresh |
| `app/models/concerns/listing_stateable.rb` | Listing state transitions (activate, deactivate, archive) |
| `app/jobs/ntfy_notification_job.rb` | Existing notification job pattern (model for webhook job) |
| `app/controllers/api_public/v1/base_controller.rb:21-22` | Cache header configuration |
| `app/models/pwb/website_integration.rb` | Integration model (could store webhook config alternatively) |
