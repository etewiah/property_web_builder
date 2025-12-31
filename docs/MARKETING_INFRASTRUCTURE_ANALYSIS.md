# Marketing/Social Media Infrastructure Analysis

## Executive Summary

PropertyWebBuilder has a **solid foundation** for marketing and social media features with existing infrastructure for:
- Social media link management
- Email templates and delivery systems
- Background job processing
- Analytics tracking
- Media library with image processing
- Multi-tenant content management
- Theme and branding configuration

This document outlines what's available, what gaps exist, and recommendations for building marketing features.

---

## 1. EXISTING SOCIAL MEDIA INFRASTRUCTURE

### 1.1 Social Media Link Management

**Model:** `Pwb::WebsiteSocialLinkable` concern
**Location:** `/app/models/concerns/pwb/website_social_linkable.rb`

**Capabilities:**
- Stores URLs for 8 social media platforms:
  - Facebook, Instagram, LinkedIn, YouTube, Twitter, WhatsApp, Pinterest
  - Plus generic `social_media` JSON field on Website model
- Links stored in `pwb_links` table with `social_media` placement enum
- Memoized caching to avoid N+1 queries
- Admin methods to retrieve and update links

**Current Usage:**
- Footer template displays social icons (via `social_media_link` helper)
- Page parts registry includes `footer_social_links` legacy component

**Code Example:**
```ruby
# Website model can access:
website.social_media_facebook  # => "https://facebook.com/..."
website.social_media_instagram # => "https://instagram.com/..."
website.update_social_media_link("facebook", "https://facebook.com/agencyname")
```

**Gaps:**
- No sharing widgets for individual properties or blog posts
- No social media feed integration
- No scheduled posting capabilities
- No analytics on social shares

---

## 2. EMAIL & MESSAGING INFRASTRUCTURE

### 2.1 Email Templates System

**Model:** `Pwb::EmailTemplate`
**Location:** `/app/models/pwb/email_template.rb`

**Capabilities:**
- Website-scoped custom email templates
- Support for multiple template types:
  - Enquiry emails (general & property-specific)
  - Auto-reply emails to visitors
  - Property alerts (new listing & price changes)
  - User emails (welcome & password reset)
- Liquid template support with dynamic variable substitution
- HTML and plain text email bodies
- Template preview with sample data

**Template Variables Supported:**
```ruby
# General enquiry: visitor_name, visitor_email, visitor_phone, message, website_name
# Property enquiry: + property_title, property_reference, property_url
# Price alerts: subscriber_name, property_title, old_price, new_price, property_url
# User emails: user_name, user_email, reset_url
```

### 2.2 Email Delivery System

**Configuration:**
- **Queue Adapter:** Solid Queue (Rails 8 native) for background job processing
- **Queue Name:** `:mailers`
- **Environment:** SMTP-based with support for:
  - SendGrid, Mailgun, Amazon SES, Postmark, etc.
  - Environment variable configuration:
    - `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
    - `SMTP_DOMAIN`, `SMTP_AUTH`

**Production Config:**
```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue
config.action_mailer.deliver_later_queue_name = :mailers
config.action_mailer.raise_delivery_errors = true
```

### 2.3 Mailers

**Location:** `/app/mailers/pwb/`

**Available Mailers:**
1. `EnquiryMailer` - Handles contact form and property enquiries
   - Supports custom Liquid templates OR ERB fallback
   - Tracks delivery success/failure on message records
   - Methods:
     - `general_enquiry_targeting_agency(contact, message)`
     - `property_enquiry_targeting_agency(contact, message, property)`

2. `EmailVerificationMailer` - Handles email verification
3. `ApplicationMailer` - Base mailer with helper methods

**Key Features:**
- Callbacks for tracking delivery
- Error handling with logging
- Multi-locale support
- Website-scoped email rendering

**Example Usage:**
```ruby
Pwb::EnquiryMailer.with(
  contact: contact_record,
  message: message_record
).general_enquiry_targeting_agency.deliver_later
```

---

## 3. BACKGROUND JOB INFRASTRUCTURE

### 3.1 Job Framework

**Queue System:** Solid Queue (Rails 8)
**Base Class:** `ApplicationJob` / `Pwb::ApplicationJob`
**Location:** `/app/jobs/`

**Existing Jobs:**
1. `UpdateExchangeRatesJob` - Currency exchange rate updates
2. `CleanupOrphanedBlobsJob` - Media cleanup
3. `RefreshPropertiesViewJob` - Materialized view updates
4. `NtfyNotificationJob` - Push notifications for property listings/inquiries

**Available Job Patterns:**
- Tenant-aware jobs (scoped to specific website)
- Retry mechanisms
- Error handling
- Scheduled execution support

**Example Job:**
```ruby
class Pwb::UpdateExchangeRatesJob < Pwb::ApplicationJob
  queue_as :default
  
  def perform
    # Job implementation
  end
end
```

### 3.2 Scheduling Capability

Solid Queue supports:
- Delayed job scheduling via `perform_later`
- Cron-like scheduling (can be configured)
- Recurring job patterns

---

## 4. IMAGE & MEDIA HANDLING

### 4.1 Media Library Model

**Model:** `Pwb::Media`
**Location:** `/app/models/pwb/media.rb`

**Capabilities:**
- ActiveStorage integration for file storage
- Multi-tenant media folders
- Image variants (thumbnail, small, medium, large)
- Metadata extraction:
  - Dimensions (width/height)
  - File size, content type
  - Checksums for integrity
- Tagging system
- Usage tracking
- Search by filename, title, alt text, description

**Supported File Types:**
- Images: JPEG, PNG, GIF, WebP, SVG
- Documents: PDF, Word, Excel
- Text: CSV, plain text

**Storage Options:**
- Cloudflare R2 (production)
- Local disk (development)
- Any S3-compatible service

**Methods:**
```ruby
media = Pwb::Media.find(id)
media.url                      # Original file URL
media.variant_url(:thumb)      # Thumbnail (150x150)
media.variant_url(:medium)     # 600x600
media.add_tag("marketing")     # Tagging
media.record_usage!            # Track usage
```

### 4.2 Related Models

**ContentPhoto & WebsitePhoto:**
- `Pwb::ContentPhoto` - Photos attached to content blocks
- `Pwb::WebsitePhoto` - Website-level photos (branding)
- `Pwb::PropPhoto` - Property images

**All use ActiveStorage with image processing capabilities**

---

## 5. CONTENT MANAGEMENT SYSTEM

### 5.1 Page System

**Model:** `Pwb::Page`
**Location:** `/app/models/pwb/page.rb`

**Capabilities:**
- Multi-locale page support via Mobility gem
- SEO fields: `seo_title`, `meta_description`
- Navigation placement:
  - Top navigation with sort order
  - Footer with sort order
- Visibility control
- Slug-based routing
- Page parts system for flexible layouts

**Multi-language Support:**
```ruby
page = Pwb::Page.find(id)
page.raw_html_en     # English content
page.raw_html_es     # Spanish content
page.raw_html_fr     # French content
# Supports all locales configured for website
```

### 5.2 Page Parts System

**Framework:** Liquid template-based modular components
**Registry:** `Pwb::PagePartLibrary`
**Location:** `/app/views/pwb/page_parts/`

**Available Page Part Categories:**

1. **Heroes** (3 templates)
   - Centered hero with CTA
   - Split hero (content + image)
   - Hero with property search

2. **Features** (2 templates)
   - 3-column feature grid
   - 4-column icon cards with colors

3. **Testimonials** (2 templates)
   - Carousel with slide navigation
   - Grid layout

4. **Call-to-Action** (2 templates)
   - Full-width banner CTA
   - Split CTA with side image

5. **Statistics** (1 template)
   - Animated number counters

6. **Teams** (1 template)
   - Team member grid with social links

7. **Galleries** (1 template)
   - Image grid with lightbox

8. **Pricing** (1 template)
   - 3-column pricing comparison

9. **FAQs** (1 template)
   - Expandable accordion

10. **Content** (Various)
    - HTML content blocks
    - Footer content
    - Search component

**Page Part Definition Example:**
```ruby
# From PagePartLibrary::DEFINITIONS
'heroes/hero_split' => {
  category: :heroes,
  label: 'Split Hero',
  description: 'Two-column hero with content and image',
  fields: %w[title subtitle description cta_text cta_link image image_alt]
}
```

### 5.3 Liquid Template Rendering

**Engine:** Liquid 5.3
**Use Cases:**
- Page part rendering
- Email template rendering
- Dynamic content personalization

**Example Template:**
```liquid
{% if property %}
  <h1>{{ property.title }}</h1>
  <p>Price: {{ property.price | currency }}</p>
{% endif %}
```

---

## 6. BRANDING & THEMING INFRASTRUCTURE

### 6.1 Website Branding

**Model:** `Pwb::Website`
**Key Branding Fields:**

```ruby
# Logo
main_logo_url              # Primary logo URL
favicon_url                # Favicon

# Company Info
company_display_name       # Display name
site_type                  # residential, commercial, vacation_rental

# Localization
supported_locales          # Available languages
default_client_locale      # Default language for visitors
default_admin_locale       # Admin language

# Colors & Styling
selected_palette           # Color scheme name
palette_mode               # dynamic, light_only, dark
compiled_palette_css       # Generated CSS from palette
raw_css                    # Custom CSS
style_variables_for_theme  # Theme-specific variables

# Google Fonts
google_font_name           # Selected font
```

### 6.2 Theme System

**Model:** `Pwb::Theme` (via `active_hash`)
**Location:** `/app/themes/`

**Capabilities:**
- Multiple themed layouts
- Theme-specific styling
- Assets per theme
- Responsive design with Tailwind CSS

**Website Theming:**
```ruby
website.theme_name                    # Current theme
website.available_themes              # List of available themes
website.style_variables_for_theme     # Theme config
```

### 6.3 Styling System

**Concerns:**
- `Pwb::WebsiteStyleable` - Style management
- Palette mode: dynamic, light, dark
- Custom CSS support
- Color palette compilation

---

## 7. ANALYTICS INFRASTRUCTURE

### 7.1 Visitor Tracking (Ahoy)

**Gem:** `ahoy_matey` v5.0
**Models:**
- `Ahoy::Visit` - Visitor sessions
- `Ahoy::Event` - Tracked events

**Visit Data Captured:**
```ruby
# Ahoy::Visit fields:
visit_token          # Unique session ID
visitor_token        # Unique visitor ID
browser, os, device_type
city, region, country
landing_page, referrer, referring_domain

# UTM Parameters
utm_source, utm_medium, utm_campaign, utm_content, utm_term
```

**Multi-tenant Scoping:**
```ruby
website = Pwb::Website.find(1)
website.visits                    # All visits to this website
visits.where(started_at: 7.days.ago..).count  # Recent visitors
```

### 7.2 Charting & Visualization

**Gems:**
- `chartkick` v5.0 - Beautiful charts
- `groupdate` v6.0 - Time-based data grouping

**Common Analytics Patterns:**
```ruby
# Time-series analytics
visits.group_by_hour(:started_at).count
visits.group_by_day(:started_at).count

# UTM source analysis
visits.group(:utm_source).count
visits.group(:utm_campaign).count

# Geography
visits.group(:country).count
visits.group(:city).count
```

### 7.3 Third-Party Analytics

**Native Integrations:**
- `analytics_id` field on Website
- `analytics_id_type` enum (Google Analytics, etc.)
- Available in serialized website JSON

---

## 8. PUBLIC API INFRASTRUCTURE

### 8.1 API Structure

**Location:** `/app/controllers/api_public/v1/`

**Available Endpoints:**
- `AuthController` - OAuth/token management
- `PropertiesController` - Property listings
- `PagesController` - Page content
- `LinksController` - Navigation links
- `SiteDetailsController` - Website configuration
- `TranslationsController` - Multi-language content
- `WidgetsController` - Embeddable widgets

**Base Controller:** `ApiPublic::V1::BaseController`

**Use Cases:**
- Embed property listings on external sites
- Syndicate content via API
- Mobile app data delivery
- Widget integration

---

## 9. MULTI-TENANCY SUPPORT

### 9.1 Tenant Scoping

**Gem:** `acts_as_tenant` v1.0

**Automatic Scoping:**
```ruby
# All queries automatically scoped to current_website
Pwb::Page.all              # Only pages for current website
Pwb::Link.all              # Only links for current website
Pwb::Media.all             # Only media for current website
```

**Multi-tenant Models:**
- Website (tenant root)
- User (with memberships for multi-website access)
- Pages, Links, Content
- Media, Images
- Email Templates
- Analytics (visits, events)

**Tenant-Aware Jobs:**
```ruby
# Jobs automatically set tenant context
class Pwb::SocialMediaSyncJob < Pwb::ApplicationJob
  def perform(website_id)
    Pwb::Current.website = Pwb::Website.find(website_id)
    # Job logic is tenant-scoped
  end
end
```

---

## 10. CONTACT & MESSAGE TRACKING

### 10.1 Contact & Message Models

**Models:**
- `Pwb::Contact` - Visitor contact information
- `Pwb::Message` - Messages from contact forms

**Message Fields:**
```ruby
# Pwb::Message
title                # Subject/title
content              # Message content
origin_email         # Visitor email
delivery_email       # Where to send responses
delivery_success     # Boolean flag
delivery_error       # Error message if failed
delivered_at         # Timestamp
```

**Use for Marketing:**
- Build email lists from enquiries
- Track lead sources
- Newsletter signup integration

---

## 11. GAPS & MISSING FEATURES

### Critical Gaps

| Feature | Status | Gap Description |
|---------|--------|-----------------|
| **Social Sharing** | Not implemented | No share buttons, meta tags, or share counting |
| **Email Marketing/Campaigns** | Partial | Email templates exist, no campaign/newsletter system |
| **Social Media Posting** | Not implemented | No integration with Facebook, Instagram, LinkedIn APIs |
| **Content Calendar** | Not implemented | No scheduling or editorial calendar |
| **Property Syndication** | Basic | API exists but no feed generation (RSS, data feeds) |
| **SEO Optimization** | Partial | Meta fields exist, no bulk SEO tools, XML sitemap limited |
| **Lead Nurturing** | Not implemented | No email sequences or drip campaigns |
| **CRM Integration** | Minimal | Contact tracking exists but no CRM sync |
| **Influencer/Affiliate** | Not implemented | No tracking or payment system |
| **Video Hosting** | Not implemented | No native video support (YouTube only via embeds) |

### Minor Gaps

- No Open Graph/Twitter Card generation
- No A/B testing framework
- No referral tracking
- No UTM parameter generation helper
- No email list segmentation
- No SMS marketing
- No push notification templates (has infrastructure but limited)

---

## 12. INFRASTRUCTURE ASSESSMENT

### Strong Points

✅ **Multi-tenant Architecture** - Fully supports tenant-scoped marketing features
✅ **Email System** - Production-ready with custom templates
✅ **Background Jobs** - Solid Queue ready for async marketing operations
✅ **Media Management** - Robust image handling with variants
✅ **Content Management** - Flexible page parts system
✅ **Analytics Foundation** - Ahoy tracking + chartkick visualization ready
✅ **API-Ready** - Public APIs for integration and syndication
✅ **Branding Controls** - Full website customization capabilities
✅ **Localization** - Multi-language support via Mobility gem

### Requires Development

🔨 **Sharing Features** - Need social sharing widgets and meta tag generation
🔨 **Campaign Management** - Email/social campaign scheduling system
🔨 **Social Media Integration** - API integrations for posting and analytics
🔨 **SEO Tools** - Bulk optimization tools, XML sitemaps, schema markup
🔨 **Lead Management** - Nurture sequences, segmentation, automation
🔨 **Tracking & Attribution** - UTM tracking, conversion funnel analytics

---

## 13. RECOMMENDATION FOR MARKETING FEATURES

### Phase 1: Quick Wins (2-3 weeks)
1. **Social Sharing Widget** (Share buttons on properties/pages)
2. **Email Newsletter System** (Basic list + send campaign)
3. **SEO Meta Tags Auto-generation** (Using page titles/descriptions)
4. **Website Analytics Dashboard** (Ahoy data visualization)
5. **Basic UTM Parameter Helper** (For campaign tracking)

### Phase 2: Social Integration (4-6 weeks)
1. **Facebook Share API Integration** (Scheduled posting)
2. **Instagram Integration** (Image feed, post scheduling)
3. **LinkedIn Company Updates** (Article sharing)
4. **Social Media Analytics** (Engagement metrics)
5. **Social Feed Display Widget** (Embed feeds on site)

### Phase 3: Advanced Marketing (6-8 weeks)
1. **Email Automation** (Drip campaigns, sequences)
2. **Content Calendar** (Editorial planning)
3. **Lead Scoring** (Based on visits, engagement)
4. **Referral System** (Tracking referral sources)
5. **A/B Testing Framework** (Email/page variants)

### Phase 4: Enterprise Features (8+ weeks)
1. **CRM Sync** (Salesforce, HubSpot integrations)
2. **Advanced Segmentation** (RFM analysis, cohorts)
3. **SMS Marketing** (SMS campaigns)
4. **Video Hosting** (Native video management)
5. **Influencer/Affiliate Program** (Commission tracking)

---

## 14. KEY FILES & REFERENCES

### Models to Extend
- `/app/models/pwb/website.rb` - Add marketing fields
- `/app/models/pwb/page.rb` - Add social share tracking
- `/app/models/pwb/message.rb` - Add marketing attributes
- `/app/models/pwb/media.rb` - Already has tags, usage tracking

### Controllers to Create
- `/app/controllers/pwb/marketing/campaigns_controller.rb`
- `/app/controllers/pwb/marketing/email_campaigns_controller.rb`
- `/app/controllers/pwb/marketing/social_integrations_controller.rb`
- `/app/controllers/pwb/marketing/analytics_controller.rb`

### Jobs to Create
- `/app/jobs/pwb/send_email_campaign_job.rb`
- `/app/jobs/pwb/sync_social_media_job.rb`
- `/app/jobs/pwb/generate_sitemap_job.rb`
- `/app/jobs/pwb/calculate_lead_scores_job.rb`

### Views/Liquid Templates
- `/app/views/pwb/page_parts/social_sharing_widget.liquid`
- `/app/views/pwb/page_parts/newsletter_signup.liquid`
- `/app/views/pwb/admin/marketing/campaigns/` (admin interface)

### Database Migrations Needed
```ruby
# Marketing features will need:
- create_email_campaigns
- create_campaign_recipients
- create_social_posts
- create_utm_tracking
- create_lead_scores
- create_referral_codes
```

### Configuration Files
- `.env` variables for social API keys
- `config/marketing.yml` - Feature flags
- `config/email_defaults.yml` - Default email settings

---

## 15. DEVELOPMENT APPROACH

### Use Existing Patterns

1. **Follow Email Template Pattern** (for campaign templates)
   ```ruby
   # Use Liquid rendering like EmailTemplate does
   renderer = EmailTemplateRenderer.new(
     website: website,
     template_key: "campaign.weekly"
   )
   ```

2. **Follow Job Pattern** (for async marketing)
   ```ruby
   # Use TenantAwareJob concern
   class Pwb::SendCampaignJob < Pwb::ApplicationJob
     include Pwb::TenantAwareJob
   end
   ```

3. **Follow Page Parts Pattern** (for marketing components)
   ```liquid
   {%- liquid
     assign newsletter_title = newsletter.title
     assign newsletter_description = newsletter.description
   -%}
   ```

4. **Follow Multi-tenancy Pattern**
   ```ruby
   # Always scope to current_website
   Pwb::Current.website = website
   # Now all queries are scoped
   ```

### Leverage Existing Infrastructure

- **Email delivery:** Use existing ActionMailer + Solid Queue
- **Media:** Use existing Media model + ActiveStorage
- **Analytics:** Use existing Ahoy + Chartkick
- **Localization:** Use existing Mobility gem
- **Styling:** Use existing Tailwind CSS + theme system
- **API:** Extend existing API endpoints

---

## 16. SECURITY CONSIDERATIONS

### For Marketing Features

1. **Email Safety**
   - Validate all email addresses
   - Use AWS SES v2 bounce/complaint handling
   - Implement unsubscribe tokens (RFCs 2369, 8058)

2. **Social Media API Tokens**
   - Store in environment variables only
   - Rotate tokens regularly
   - Rate limit API calls

3. **Data Privacy**
   - GDPR compliance for email lists
   - Consent tracking for newsletters
   - Right to be forgotten implementation

4. **Input Validation**
   - Sanitize all user input for templates
   - Validate URLs in social links
   - Check image dimensions/types

---

## 17. PERFORMANCE NOTES

### Query Optimization

```ruby
# Use existing includes to avoid N+1
Website.includes(:links, :media, :page_contents).find(id)

# Memoization pattern used in WebsiteSocialLinkable
@social_media_links_cache ||= links.where(slug: slugs).index_by(&:slug)
```

### Caching Recommendations

- Cache website branding in Redis
- Cache email templates with TTL
- Use fragment caching for marketing components
- Cache analytics queries (regenerate daily)

### Background Processing

- Use Solid Queue for bulk operations
- Set job timeouts for long-running tasks
- Implement exponential backoff for retries

---

## Conclusion

PropertyWebBuilder has **strong foundational infrastructure** for marketing and social media features. The multi-tenant architecture, email system, media handling, and analytics tracking provide a solid base. Development should focus on:

1. Social sharing and syndication
2. Email campaign management
3. Social media API integrations
4. SEO optimization tools
5. Lead tracking and automation

All of these can be built using existing patterns and infrastructure already in place.
