# Marketing Infrastructure Documentation

Welcome! This directory contains comprehensive documentation about PropertyWebBuilder's marketing and social media capabilities.

## Start Here 👇

### 1. **New to this codebase?**
→ Read **[MARKETING_EXPLORATION_SUMMARY.md](MARKETING_EXPLORATION_SUMMARY.md)** first
- 10-minute overview of what exists and what's missing
- Architecture overview
- Quick wins you can build today

### 2. **Ready to build something?**
→ Use **[MARKETING_QUICK_REFERENCE.md](MARKETING_QUICK_REFERENCE.md)** as your cheat sheet
- Code examples for every feature
- Copy-paste ready snippets
- Common patterns to follow
- Debugging tips

### 3. **Planning what to build?**
→ Check **[MARKETING_FEATURE_MATRIX.md](MARKETING_FEATURE_MATRIX.md)** for the full feature grid
- Status of 100+ marketing features
- Priority indicators
- Infrastructure readiness scores
- Development roadmap suggestions

### 4. **Going deep on architecture?**
→ Study **[MARKETING_INFRASTRUCTURE_ANALYSIS.md](MARKETING_INFRASTRUCTURE_ANALYSIS.md)** for details
- Complete technical breakdown
- Security considerations
- Performance optimization
- File locations and references

## Quick Navigation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **SUMMARY** | Overview & getting started | 10 min |
| **QUICK_REFERENCE** | Code examples & patterns | 5-15 min lookup |
| **FEATURE_MATRIX** | Capabilities & gaps | 10 min |
| **ANALYSIS** | Deep technical dive | 30 min |

## Infrastructure Summary

### What's Production-Ready ✅
- Email templates with Liquid rendering
- Async email delivery via Solid Queue
- Social media link storage (8 platforms)
- Media library with image variants
- Multi-language page system
- 30+ page part templates
- Visitor analytics with Ahoy
- Multi-tenant architecture
- Contact form & lead capture

### What Needs Building 🔨
- Email campaigns & newsletters
- Social media posting (FB, IG, LinkedIn)
- Content calendar & scheduling
- Lead scoring & segmentation
- CRM integrations
- Email automation sequences
- Advanced analytics dashboards

## Key Statistics

- **94% infrastructure ready** for marketing features
- **40+ existing features** fully implemented
- **30+ page part templates** available
- **8 social platforms** supported
- **6 email template types** pre-built
- **10+ languages** supported

## Architecture at a Glance

```
Website (tenant root)
├── Email System (ActionMailer + Liquid templates)
├── Media Library (ActiveStorage + image variants)
├── CMS Pages (30+ flexible page parts)
├── Analytics (Ahoy tracking + chartkick)
├── Contacts & Messages (lead capture)
└── Background Jobs (Solid Queue for async)

All tenant-scoped automatically via acts_as_tenant
```

## Quick Start: Add a Feature

1. **Choose what to build** → Check [MARKETING_FEATURE_MATRIX.md](MARKETING_FEATURE_MATRIX.md)
2. **Find code examples** → Look in [MARKETING_QUICK_REFERENCE.md](MARKETING_QUICK_REFERENCE.md)
3. **Understand patterns** → Read relevant sections in [MARKETING_INFRASTRUCTURE_ANALYSIS.md](MARKETING_INFRASTRUCTURE_ANALYSIS.md)
4. **Follow conventions** → Use patterns from existing code (email, jobs, pages)
5. **Test thoroughly** → See security & performance notes in analysis doc

## Recommended Development Order

### Phase 1: Quick Wins (Weeks 1-2)
- [ ] Analytics dashboard UI
- [ ] Social share buttons
- [ ] Email newsletter system

### Phase 2: Core Features (Weeks 3-6)
- [ ] Email campaigns
- [ ] Lead segmentation
- [ ] Content calendar

### Phase 3: Integration (Weeks 7-10)
- [ ] Social media posting
- [ ] Email automation
- [ ] CRM sync

### Phase 4: Enterprise (Weeks 11+)
- [ ] SMS marketing
- [ ] Video hosting
- [ ] Advanced analytics

## Key Models Reference

```ruby
# Social Media
Pwb::Website.includes(WebsiteSocialLinkable)
  .social_media_facebook => "URL"

# Email Templates
Pwb::EmailTemplate.find_for_website(website, "enquiry.general")

# Media
Pwb::Media.find(id).variant_url(:medium)

# Pages & Content
Pwb::Page.find(id)  # Multi-language support
Pwb::PagePart       # 30+ templates

# Analytics
Ahoy::Visit.group_by_day(:started_at).count
Ahoy::Event.where(name: "Property View")

# Lead Capture
Pwb::Message.where(website: website)
Pwb::Contact.find(id)
```

## Configuration

### Production Email
```env
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=sg_xxxxx
```

### Media Storage
```env
AWS_ENDPOINT_URL_S3=https://xxx.r2.cloudflarestorage.com
AWS_BUCKET=your-bucket
```

### Job Processing
- Queue: Solid Queue (Rails 8)
- Mailer Queue: `:mailers`
- Default Queue: `:default`

## Important Patterns

### 1. Async Email
```ruby
Pwb::EnquiryMailer.with(contact: obj, message: obj)
  .general_enquiry_targeting_agency.deliver_later
```

### 2. Tenant Scoping
```ruby
Pwb::Current.website = website
Pwb::Page.all  # Automatically scoped
```

### 3. Multi-Language
```ruby
page.page_title_en = "English"
page.page_title_es = "Spanish"
```

### 4. Media Variants
```ruby
media.variant_url(:thumb)   # 150x150
media.variant_url(:medium)  # 600x600
```

### 5. Analytics
```ruby
website.visits.group_by_day(:started_at).count
```

## File Organization

```
app/
├── models/pwb/          → Core models
├── mailers/pwb/         → Email senders
├── jobs/pwb/            → Background jobs
├── controllers/pwb/     → Admin & API
├── views/pwb/           → Templates & partials
│   └── page_parts/      → 30+ layout templates
└── lib/pwb/             → Utilities & registry

db/
├── migrate/             → Schema
└── seeds/               → Seed data

docs/
├── MARKETING_EXPLORATION_SUMMARY.md    → START HERE
├── MARKETING_QUICK_REFERENCE.md        → Code examples
├── MARKETING_FEATURE_MATRIX.md         → Capabilities grid
└── MARKETING_INFRASTRUCTURE_ANALYSIS.md → Deep dive
```

## Common Tasks

### Send Email to Contacts
```ruby
contacts = Pwb::Contact.where(website: website)
template = Pwb::EmailTemplate.find_for_website(website, "newsletter.weekly")

contacts.each do |contact|
  # Send email (needs campaign system to build)
end
```

### Track Custom Event
```ruby
# In controller
ahoy.track("Property Viewed", {property_id: 123})
ahoy.track("Lead Generated", {type: "contact_form"})
```

### Get Analytics
```ruby
website = Pwb::Website.find(1)
visits = website.visits

# By day
visits.group_by_day(:started_at).count

# By source
visits.group(:utm_source).count

# By geography
visits.group(:country).count
```

### Create Page Part
```ruby
# Use any of 30+ templates
page = Pwb::Page.find(id)
page_part = Pwb::PagePart.create(
  page_slug: page.slug,
  page_part_key: "heroes/hero_centered",
  website_id: website.id,
  settings: {
    title: "Welcome",
    subtitle: "Featured Properties"
  }
)
```

## Troubleshooting

### Email not sending?
- Check SMTP config in env variables
- Verify Solid Queue is running
- Check mailer queue in job dashboard

### Analytics data missing?
- Ensure Ahoy is initialized in application.html.erb
- Check Ahoy::Visit and Ahoy::Event tables
- Verify website_id is being set

### Media variants not working?
- Check image processing gem is installed
- Verify ActiveStorage is configured
- Check file storage backend

### Multi-tenancy issues?
- Verify Pwb::Current.website is set
- Check acts_as_tenant is properly included
- Query logs should show website_id in WHERE clause

## Security Checklist

- ✅ Email: SMTP credentials in env vars only
- ✅ Media: File type validation
- ✅ APIs: CSRF protection + authentication
- ⚠️ Email: Implement unsubscribe (RFC 2369)
- ⚠️ Social: Store tokens securely
- ⚠️ Forms: Validate & sanitize input

## Performance Tips

- Use `Pwb::Current.website` for tenant scoping
- Cache website config in Redis
- Batch analytics queries with `group_by`
- Use async email delivery (deliver_later)
- Pre-generate image variants
- Index frequently queried columns

## Getting Help

1. **Code examples** → See MARKETING_QUICK_REFERENCE.md
2. **Architecture questions** → See MARKETING_INFRASTRUCTURE_ANALYSIS.md
3. **Feature status** → See MARKETING_FEATURE_MATRIX.md
4. **Getting started** → See MARKETING_EXPLORATION_SUMMARY.md

## Next Steps

1. Read [MARKETING_EXPLORATION_SUMMARY.md](MARKETING_EXPLORATION_SUMMARY.md)
2. Review [MARKETING_FEATURE_MATRIX.md](MARKETING_FEATURE_MATRIX.md)
3. Pick a feature to build
4. Use [MARKETING_QUICK_REFERENCE.md](MARKETING_QUICK_REFERENCE.md) for code
5. Follow patterns from [MARKETING_INFRASTRUCTURE_ANALYSIS.md](MARKETING_INFRASTRUCTURE_ANALYSIS.md)

---

**Last Updated**: 2025-12-31  
**Status**: Documentation Complete  
**Infrastructure Ready**: 94%
