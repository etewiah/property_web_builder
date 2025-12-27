# Email Implementation Quick Reference

## What Email Functionality Exists?

### ✓ Working
- Contact form enquiry emails (general contact form)
- Property inquiry emails (from property pages)
- Devise authentication emails (password reset, confirmation)
- Multi-tenant email routing (per-website contact addresses)
- GraphQL mutation support for email submissions
- Push notification integration (via ntfy.sh, not traditional email)

### ✗ Missing
- SMTP server configuration (production)
- Default from address (commented out)
- Email delivery job processing (synchronous only)
- Error handling and retry logic
- Email delivery tracking/status
- Rate limiting
- Text-only email versions
- Bounce handling

---

## Email Endpoints

### Contact Submission
- **Controller:** `Pwb::ContactUsController#contact_us_ajax`
- **Method:** POST to `/pwb/contact_us_ajax`
- **Mailer:** `Pwb::EnquiryMailer#general_enquiry_targeting_agency`

### Property Inquiry
- **Controller:** `Pwb::PropsController#request_property_info_ajax`
- **Method:** POST to `/pwb/request_property_info_ajax`
- **Mailer:** `Pwb::EnquiryMailer#property_enquiry_targeting_agency`

### GraphQL Mutation
- **Mutation:** `Mutations::SubmitListingEnquiry`
- **Endpoint:** GraphQL query endpoint
- **Mailer:** Same as property inquiry above

---

## Configuration Files

```
Production SMTP Setup (CURRENTLY COMMENTED OUT):
├── config/environments/production.rb
│   └── Uncomment config.action_mailer.smtp_settings

Current From Address:
├── config/initializers/devise.rb
│   └── config.mailer_sender = "PLACEHOLDER - CHANGE ME"

Email Layout:
├── app/views/layouts/mailer.html.erb
│   └── Minimal HTML structure

Per-Website Contact Emails:
├── Agency model (pwb_agencies table)
│   ├── email_for_general_contact_form
│   └── email_for_property_contact_form
```

---

## Database Models

### Contact (pwb_contacts)
- Stores visitor/contact information
- One-to-many with Messages
- Multi-tenant via website_id

### Message (pwb_messages)
- Stores email/inquiry details
- Fields: title, content, origin_email, delivery_email, delivery_success
- **Note:** delivery_success not currently updated

### User (pwb_users) - Devise
- Authentication and password reset emails
- Standard Devise gem functionality

---

## Email Delivery Methods

| Context | Method | Blocking? | Async? |
|---------|--------|-----------|--------|
| Contact form | `deliver_now` | Yes | No |
| Property inquiry | `deliver` | Yes | No |
| Devise emails | `deliver_now` | Yes | No |
| Push notifications | `NtfyNotificationJob.perform_later` | No | Yes |

---

## Mailer Classes

### Pwb::ApplicationMailer
- Base class for custom mailers
- Uses "mailer" layout
- No default from address configured

### Pwb::EnquiryMailer
- `general_enquiry_targeting_agency(contact, message)`
- `property_enquiry_targeting_agency(contact, message, property)`

### Devise::Mailer
- Implicit Devise gem mailer
- Customized templates in app/views/devise/mailer/

---

## Email Templates

```
app/views/layouts/mailer.html.erb              [Base layout]
app/views/pwb/mailers/
├── general_enquiry_targeting_agency.html.erb
└── property_enquiry_targeting_agency.html.erb
app/views/devise/mailer/
├── confirmation_instructions.html.erb
├── reset_password_instructions.html.erb
├── password_change.html.erb
└── unlock_instructions.html.erb
```

---

## Environment Configuration Summary

```ruby
# Development
delivery_method = :smtp (default, not configured)
raise_delivery_errors = false
default_url_options = { host: "localhost", port: 3000 }

# Test
delivery_method = :test
raise_delivery_errors = N/A (test mode)
default_url_options = { host: "example.com" }

# E2E
delivery_method = :smtp (default, not configured)
raise_delivery_errors = false
default_url_options = { host: "localhost", port: 3001 }

# Production
delivery_method = :smtp (SMTP SETTINGS COMMENTED OUT!)
raise_delivery_errors = not set (defaults to true)
default_url_options = { host: "example.com" }
```

---

## Key Issues At a Glance

### Critical (Production Blocker)
1. **SMTP not configured** → Emails won't send
2. **No from address** → Emails may be rejected
3. **Synchronous delivery** → Blocks HTTP requests
4. **No error handling** → Silent failures

### Important (Production Risk)
5. **No delivery tracking** → Cannot verify success
6. **No retry mechanism** → Transient failures = lost emails
7. **No rate limiting** → Spam/DoS possible

### Nice to Have (Enhancement)
8. No text-only versions
9. No email validation
10. No bounce handling

---

## Testing

### Test Location
`spec/mailers/pwb/enquiry_mailer_spec.rb`

### Preview Location
`spec/mailers/previews/pwb/enquiry_mailer_preview.rb`

### How to Test Locally
1. Submit contact form at `/pwb/contact_us`
2. Check `ActionMailer::Base.deliveries` array in Rails console
3. View preview at `/rails/mailers/pwb/enquiry_mailer`

---

## Data Flow Diagram

```
User Form
   ↓
find_or_initialize Contact (by email)
   ↓
Create Message record
   ↓
Save both to database
   ↓
Call Mailer#method(contact, message, [property])
   ↓
Render HTML template with variables
   ↓
deliver_now → SMTP
   ↓
HTTP Response (after email sent or timeout)
   ↓
Optional: Fire NtfyNotificationJob (push notification)
```

---

## i18n Support

**Available Languages:** en, es, de, pt-BR, pt-PT, bg, ro

**Mailer Translations:** `config/locales/en.yml`

```yaml
mailers:
  general_enquiry_targeting_agency:
    title: General enquiry from your website
  property_enquiry_targeting_agency:
    title: Enquiry regarding a property
```

---

## Multi-Tenancy Email Isolation

- Each website has separate contact addresses
- Messages scoped to website via website_id
- Contacts scoped to website via website_id
- No cross-tenant email leakage observed

---

## Related Components

### Push Notifications (ntfy.sh)
- Async alternative to email
- Via `NtfyNotificationJob`
- Can be enabled per-website
- Configured in `Website` model:
  - `ntfy_enabled` (boolean)
  - `ntfy_server_url`
  - `ntfy_topic_prefix`
  - `ntfy_access_token`

### Fields Involved in Email Submission
From `Message` model:
- `title` - email subject
- `content` - email body
- `origin_email` - from address (visitor)
- `delivery_email` - to address (agency)
- `origin_ip` - metadata
- `user_agent` - metadata
- `url` - referrer
- `locale` - language
- `delivery_success` - **not tracked**

---

## Production Deployment Checklist

- [ ] Configure SMTP credentials in `config/environments/production.rb`
- [ ] Set proper `from` address in `Pwb::ApplicationMailer`
- [ ] Set proper `from` address for Devise in `devise.rb`
- [ ] Update `default_url_options` host for production domain
- [ ] Add background job processing for emails (use DelayedJob or Sidekiq)
- [ ] Add error handling and logging
- [ ] Test email delivery end-to-end
- [ ] Monitor ActionMailer errors in production
- [ ] Consider adding delivery tracking
- [ ] Consider rate limiting on contact forms
- [ ] Update email templates for branding

---

## Common Patterns

### Sending a Custom Email

```ruby
# Create mailer method
def my_custom_email(user, data)
  @user = user
  @data = data
  mail(to: user.email, subject: "My Subject")
end

# Call it
MyMailer.my_custom_email(user, data).deliver_now  # blocking
MyMailer.my_custom_email(user, data).deliver_later # background job
```

### Accessing Email Data in Template

```erb
<!-- In app/views/my_mailer/my_custom_email.html.erb -->
<p>Hello <%= @user.name %></p>
<p><%= @data %></p>
```

### Testing Email Delivery

```ruby
expect {
  MyMailer.my_email(user).deliver_now
}.to change { ActionMailer::Base.deliveries.count }.by(1)

expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
```

---

## File Structure Summary

```
app/
├── mailers/pwb/
│   ├── application_mailer.rb      ← Base class (no from address!)
│   └── enquiry_mailer.rb          ← Contact form emails
├── views/
│   ├── layouts/mailer.html.erb    ← Email layout template
│   ├── pwb/mailers/               ← Enquiry email templates
│   │   ├── general_enquiry_targeting_agency.html.erb
│   │   └── property_enquiry_targeting_agency.html.erb
│   └── devise/mailer/             ← Auth email templates
│       ├── confirmation_instructions.html.erb
│       ├── reset_password_instructions.html.erb
│       ├── password_change.html.erb
│       └── unlock_instructions.html.erb
├── models/pwb/
│   ├── contact.rb                 ← Visitor contact data
│   ├── message.rb                 ← Email/inquiry data
│   └── user.rb                    ← Auth user (Devise)
├── controllers/pwb/
│   ├── contact_us_controller.rb   ← General form endpoint
│   └── props_controller.rb        ← Property inquiry endpoint
└── jobs/
    └── ntfy_notification_job.rb   ← Push notifications (async)

config/
├── environments/
│   ├── development.rb
│   ├── test.rb
│   ├── e2e.rb
│   └── production.rb              ← SMTP COMMENTED OUT!
└── initializers/
    └── devise.rb                  ← Devise config (sender placeholder)

spec/
└── mailers/pwb/
    ├── enquiry_mailer_spec.rb     ← Tests
    └── previews/enquiry_mailer_preview.rb  ← Preview
```

---

## Status Indicator

```
Production Email Readiness: YELLOW 🟡
├─ Code Quality:      GREEN ✓
├─ Functionality:     GREEN ✓
├─ Configuration:     RED ✗ (SMTP not configured)
├─ Error Handling:    RED ✗ (None implemented)
├─ Async Processing:  RED ✗ (All synchronous)
└─ Monitoring:        RED ✗ (No delivery tracking)
```

