# Marketing Infrastructure - Quick Reference Guide

## At a Glance

**What's Built:** Email templates, social media links, media library, analytics tracking, multi-tenant CMS
**What's Missing:** Email campaigns, social posting, content calendar, advanced automation
**Infrastructure Quality:** Production-ready with established patterns to follow

---

## Key Models & Their Locations

### Social Media
```
Model: Pwb::WebsiteSocialLinkable (concern)
File: app/models/concerns/pwb/website_social_linkable.rb
Platforms: Facebook, Instagram, LinkedIn, YouTube, Twitter, WhatsApp, Pinterest
Usage: website.social_media_facebook => URL
```

### Email
```
Model: Pwb::EmailTemplate
File: app/models/pwb/email_template.rb
Types: Enquiry, Auto-reply, Alerts, User emails
Rendering: Liquid templates with variable substitution
Delivery: ActionMailer + Solid Queue (async)
```

### Media & Images
```
Model: Pwb::Media
File: app/models/pwb/media.rb
Storage: ActiveStorage (Cloudflare R2 production)
Features: Variants, tagging, usage tracking, dimensions
File Types: JPG, PNG, GIF, WebP, SVG, PDF, Office docs
```

### Pages & Content
```
Models: Pwb::Page, Pwb::Content, Pwb::PagePart
Files: app/models/pwb/page.rb, app/models/pwb/content.rb
Features: Multi-language (Mobility), SEO fields, flexible layouts
Page Parts: 30+ pre-built templates (heroes, CTAs, testimonials, etc.)
```

### Analytics
```
Models: Ahoy::Visit, Ahoy::Event
Files: app/models/ahoy/visit.rb, app/models/ahoy/event.rb
Tracked: Browser, OS, device, location, referrer, UTM params
Visualization: Chartkick + Groupdate gems
```

### Contact & Messages
```
Models: Pwb::Contact, Pwb::Message
Files: app/models/pwb/contact.rb, app/models/pwb/message.rb
Fields: Email, phone, message content, delivery status
Use For: Lead capture, email list building
```

---

## Email System Quick Start

### Send an Email via Mailer
```ruby
# Using enqueued delivery (recommended)
Pwb::EnquiryMailer.with(
  contact: contact_obj,
  message: message_obj
).general_enquiry_targeting_agency.deliver_later

# Using custom template
renderer = EmailTemplateRenderer.new(
  website: website,
  template_key: "enquiry.general"
)
rendered = renderer.render({
  "visitor_name" => "John",
  "message" => "Hello",
  "website_name" => website.company_display_name
})
```

### Create Email Template
```ruby
Pwb::EmailTemplate.create(
  website: website,
  template_key: "enquiry.general",
  name: "General Enquiry Email",
  subject: "New Enquiry: {{ message.title }}",
  body_html: "<h1>Hello {{ visitor_name }}</h1><p>{{ message }}</p>",
  body_text: "Hello {{ visitor_name }}\n{{ message }}"
)
```

### Template Variables Available
```
enquiry.general: visitor_name, visitor_email, visitor_phone, message, website_name
enquiry.property: above + property_title, property_reference, property_url
alert.new_property: subscriber_name, property_title, property_price, property_url, website_name
alert.price_change: subscriber_name, old_price, new_price, property_url
user.welcome: user_name, user_email, website_name
user.password_reset: user_name, reset_url, website_name
```

---

## Media Library Quick Start

### Upload & Use Images
```ruby
# Create media record
media = Pwb::Media.create(
  website: website,
  filename: "property-hero.jpg",
  title: "Amazing Property",
  alt_text: "Front view of modern house",
  file: File.open("property.jpg"),
  tags: ["property", "hero", "featured"]
)

# Get URLs
media.url                    # Original file
media.variant_url(:thumb)    # 150x150 thumbnail
media.variant_url(:medium)   # 600x600
media.variant_url(:large)    # 1200x1200

# Track usage
media.record_usage!          # Increment usage counter
```

### Search & Filter
```ruby
# By folder
Pwb::Media.by_folder(folder)

# By tag
Pwb::Media.with_tag("featured")

# By type
Pwb::Media.images
Pwb::Media.documents

# Search
Pwb::Media.search("property").where(content_type: "image/jpeg")
```

---

## Social Links Quick Start

### Get Social URLs
```ruby
website = Pwb::Website.find(1)

# Access individual platforms
website.social_media_facebook   # => "https://facebook.com/..."
website.social_media_instagram  # => "https://instagram.com/..."
website.social_media_linkedin   # => "https://linkedin.com/..."

# Get all for admin
links = website.social_media_links_for_admin
links.each do |link|
  puts "#{link[:platform]}: #{link[:url]}"
end
```

### Update Social Links
```ruby
# Add or update
website.update_social_media_link("facebook", "https://facebook.com/newpage")
website.update_social_media_link("instagram", "https://instagram.com/agency")

# Clear cache after updates
website.clear_social_media_cache
```

---

## Analytics Quick Start

### Track Events
```ruby
# In controller, ahoy automatically tracks:
# - visit token & visitor token
# - browser, OS, device_type
# - geography (city, country)
# - referrer & UTM parameters
# - landing page

# Manual events
ahoy.track("Property View", {property_id: 123, price: 350000})
ahoy.track("Lead Generated", {type: "contact_form"})
```

### Query Analytics Data
```ruby
website = Pwb::Website.find(1)

# Visits for this website
visits = website.visits

# Time series
visits.group_by_day(:started_at).count
visits.group_by_week(:started_at).count

# Traffic sources
visits.group(:utm_source).count        # {google: 120, facebook: 45, ...}
visits.group(:utm_campaign).count

# Geographic
visits.group(:country).count
visits.group(:device_type).count

# Filtering
visits.where(started_at: 7.days.ago..)
visits.where(browser: "Chrome")
visits.where("utm_source = ?", "facebook")
```

### Display with Charts
```ruby
# In view using chartkick
<%= line_chart visits.group_by_day(:started_at).count %>
<%= column_chart visits.group(:utm_source).count %>
<%= pie_chart visits.group(:country).count %>
```

---

## Page Parts Available

### Heroes (3)
- `heroes/hero_centered` - Centered content with CTA
- `heroes/hero_split` - Content + image side-by-side
- `heroes/hero_search` - Search bar integration

### Features (2)
- `features/feature_grid_3col` - 3-column features
- `features/feature_cards_icons` - 4-column icon cards

### Testimonials (2)
- `testimonials/testimonial_carousel` - Sliding testimonials
- `testimonials/testimonial_grid` - Grid layout

### Call-to-Action (2)
- `cta/cta_banner` - Full-width banner
- `cta/cta_split_image` - Split with image

### More
- `stats/stats_counter` - Animated counters
- `teams/team_grid` - Team members (includes social links!)
- `galleries/image_gallery` - Image grid
- `pricing/pricing_table` - Pricing plans
- `faqs/faq_accordion` - Expandable FAQs

### Legacy
- `content_html` - Free-form HTML
- `footer_content_html` - Footer content
- `footer_social_links` - Social links display
- `search_cmpt` - Property search

---

## Background Jobs

### Job Base Classes
```ruby
# For tenant-scoped jobs
class Pwb::YourJob < Pwb::ApplicationJob
  include TenantAwareJob
  
  def perform(website_id, other_param)
    # Sets Pwb::Current.website automatically
  end
end

# For non-tenant jobs
class SomeGlobalJob < ApplicationJob
  def perform
    # Regular job
  end
end
```

### Enqueue Jobs
```ruby
# Immediate
Pwb::YourJob.perform_now(website.id)

# Async (recommended)
Pwb::YourJob.perform_later(website.id, extra_param)

# Scheduled
Pwb::YourJob.set(wait: 1.hour).perform_later(website.id)
Pwb::YourJob.set(wait_until: Time.zone.tomorrow).perform_later(website.id)
```

### Queue Adapter
```
Solid Queue (Rails 8 native)
Queue names: :default, :mailers, :urgent
Configuration: config/environments/production.rb
```

---

## Multi-Tenancy

### Scope to Current Website
```ruby
Pwb::Current.website = website

# Now all queries are automatically scoped
Pwb::Page.all           # Only pages for this website
Pwb::Link.all           # Only links for this website
Pwb::Media.all          # Only media for this website
Pwb::EmailTemplate.all  # Only templates for this website
```

### In Controllers
```ruby
# set_current_website filter automatically handles this
# Use Pwb::Current.website to access

def show
  website = Pwb::Current.website
  pages = website.pages  # Already scoped
end
```

---

## API Endpoints for Integration

### Public API (External integrations)
```
GET /api_public/v1/properties      # List properties
GET /api_public/v1/pages           # List pages
GET /api_public/v1/site_details    # Website config
GET /api_public/v1/links           # Navigation links
```

### Admin API (Dashboard)
```
GET /api/v1/website                # Website config
GET /api/v1/page                   # Page content
GET /api/v1/properties             # Properties
POST /api/v1/contacts              # Create contact/lead
```

---

## Styling & Theming

### Website Branding Fields
```ruby
website.main_logo_url              # Logo
website.company_display_name       # Company name
website.selected_palette           # Color scheme
website.google_font_name           # Font
website.raw_css                    # Custom CSS
website.style_variables_for_theme  # Theme vars
```

### Theme System
```ruby
website.theme_name          # Current theme
website.available_themes    # List of themes
website.palette_mode        # dynamic/light/dark
```

### Tailwind CSS
All styling uses Tailwind CSS (no Bootstrap)
Custom themes extend Tailwind

---

## Config & Env Variables

### Email Setup (Production)
```env
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=sg_xxxx
MAILER_HOST=example.com
```

### Storage Setup
```env
AWS_REGION=auto
AWS_ENDPOINT_URL_S3=https://xxxx.r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=xxxx
AWS_SECRET_ACCESS_KEY=xxxx
AWS_BUCKET=your-bucket
```

### Analytics & Tracking
```env
GOOGLE_ANALYTICS_ID=GA-xxxx
AHOY_COOKIES=true
```

---

## Common Patterns to Follow

### Pattern 1: Email with Custom Template
```ruby
# Check for custom template, fall back to ERB
if custom_template_available?("my.template")
  send_with_custom_template("my.template", variables: vars)
else
  mail(to: email, subject: "...", template_name: "my_template")
end
```

### Pattern 2: Tenant-Scoped Job
```ruby
class Pwb::MyJob < Pwb::ApplicationJob
  include TenantAwareJob
  queue_as :default
  
  def perform(website_id, params)
    # Automatically sets Pwb::Current.website = website
    # All queries now scoped to this website
  end
end

# Call it
Pwb::MyJob.perform_later(website.id, params)
```

### Pattern 3: Multi-Locale Content
```ruby
page = Pwb::Page.find(id)
page.page_title_en = "English Title"
page.page_title_es = "Spanish Title"
page.save

# Access in templates
page.page_title  # Returns translated version based on I18n.locale
```

### Pattern 4: Media with Variants
```ruby
media = Pwb::Media.find(id)
# Variants are generated on-demand and cached
img_tag media.variant_url(:medium), alt: media.alt_text
```

---

## Resources & Files

### Key Locations
```
Models:      app/models/pwb/
Mailers:     app/mailers/pwb/
Jobs:        app/jobs/pwb/
Controllers: app/controllers/pwb/
Views:       app/views/pwb/
Page Parts:  app/views/pwb/page_parts/
Migrations:  db/migrate/
Config:      config/
```

### Documentation Files
```
This file:                        docs/MARKETING_QUICK_REFERENCE.md
Full analysis:                    docs/MARKETING_INFRASTRUCTURE_ANALYSIS.md
Deprecated features:              docs/claude_thoughts/DEPRECATED_FEATURES.md
Multi-tenancy guide:              docs/multi_tenancy/
```

### Gems Used for Marketing
```ruby
# Email/Templates
liquid ~> 5.3              # Template engine
mobility                   # Multi-language support

# Media
image_processing ~> 1.2    # Image variants
aws-sdk-s3                 # Cloudflare R2 storage
aws-sdk-sesv2              # AWS SES for email

# Jobs & Background
solid_queue ~> 1.0         # Job queue (Rails 8)
mission_control-jobs       # Job monitoring dashboard

# Analytics
ahoy_matey ~> 5.0          # Visit/event tracking
chartkick ~> 5.0           # Charts
groupdate ~> 6.0           # Time-based grouping

# Content & Styling
tailwindcss-rails ~> 4.4   # CSS framework
dartsass-rails             # Sass support

# Admin & Monitoring
sentry-ruby                # Error tracking
lograge                    # Structured logging
rails_performance          # Performance dashboard
```

---

## What to Build Next

### Immediate (2-3 weeks)
- [ ] Social share buttons on properties
- [ ] Email newsletter system
- [ ] SEO meta tag generation
- [ ] Analytics dashboard UI
- [ ] UTM parameter helper

### Short-term (4-6 weeks)
- [ ] Facebook/Instagram integration
- [ ] Social feed widget
- [ ] Email campaign builder
- [ ] Lead source tracking
- [ ] Basic email automation

### Medium-term (6-8 weeks)
- [ ] Advanced email sequences
- [ ] Content calendar
- [ ] Lead scoring
- [ ] A/B testing
- [ ] Referral tracking

### Long-term (8+ weeks)
- [ ] CRM integrations
- [ ] SMS marketing
- [ ] Video hosting
- [ ] Affiliate program
- [ ] Advanced segmentation

---

## Debugging & Troubleshooting

### Email Issues
```ruby
# Check if template exists
Pwb::EmailTemplate.find_for_website(website, "enquiry.general")

# Check delivery method
Rails.application.config.action_mailer.delivery_method

# Test send
Pwb::EnquiryMailer.with(contact: contact, message: msg).general_enquiry_targeting_agency.deliver_now

# Check job queue
Solid::Queue::Job.all
```

### Media Issues
```ruby
# Check file storage
media.file.attached?

# Verify dimensions were extracted
media.width && media.height

# Test variant generation
media.variant_url(:thumb)  # May raise error if no image processor
```

### Analytics Issues
```ruby
# Check if ahoy is tracking
Ahoy::Visit.recent.limit(10)

# Check UTM params
Ahoy::Visit.where("utm_source != ?", nil).count
```

### Multi-tenancy Issues
```ruby
# Verify current website is set
Pwb::Current.website

# Set it manually if needed
Pwb::Current.website = Pwb::Website.find(1)

# Check if scoped correctly
Pwb::Page.count  # Uses current website
```

---

## Additional Resources

See `/docs/MARKETING_INFRASTRUCTURE_ANALYSIS.md` for:
- Detailed feature breakdown
- Comprehensive gap analysis
- Development roadmap
- Security considerations
- Performance optimization tips
