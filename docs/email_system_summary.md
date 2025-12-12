# Email System - Quick Reference

## Components at a Glance

### Mailers (2)
- **Pwb::ApplicationMailer** - Base class
  - Default from: `DEFAULT_FROM_EMAIL` env var or "PropertyWebBuilder <noreply@propertywebbuilder.com>"
  - Layout: `mailer.html.erb`

- **Pwb::EnquiryMailer** - Inquiry notifications
  - `general_enquiry_targeting_agency(contact, message)` - General contact form
  - `property_enquiry_targeting_agency(contact, message, property)` - Property inquiry

### Email Templates (2 custom + 4 Devise)
| Template | Purpose | Location |
|----------|---------|----------|
| general_enquiry_targeting_agency.html.erb | General inquiry email | `/app/views/pwb/mailers/` |
| property_enquiry_targeting_agency.html.erb | Property inquiry email | `/app/views/pwb/mailers/` |
| confirmation_instructions.html.erb | Account confirmation | `/app/views/devise/mailer/` |
| reset_password_instructions.html.erb | Password reset | `/app/views/devise/mailer/` |
| password_change.html.erb | Password changed | `/app/views/devise/mailer/` |
| unlock_instructions.html.erb | Account unlock | `/app/views/devise/mailer/` |

### Configuration

**SMTP Setup** (any provider):
```bash
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-api-key
SMTP_AUTH=plain
DEFAULT_FROM_EMAIL="My Site <noreply@mysite.com>"
MAILER_HOST=mysite.com
```

**SES-Specific Setup**:
```bash
AWS_SES_ACCESS_KEY_ID=AKIA...
AWS_SES_SECRET_ACCESS_KEY=...
AWS_SES_REGION=us-east-1
```

### Per-Website Email Configuration

**Agency Model** - Email routing per website:
- `email_primary` - Primary email
- `email_for_general_contact_form` - General inquiries route here
- `email_for_property_contact_form` - Property inquiries route here

**Flow**:
```
Visitor Submits Form
  ↓
Controller gets delivery email from: current_agency.email_for_*_contact_form
  ↓
Creates Message record with: delivery_email = ...
  ↓
EnquiryMailer.method_name(...).deliver_later
  ↓
Solid Queue processes job
  ↓
Message updated with: delivery_success=true/false, delivered_at, delivery_error
```

### Database Fields (pwb_messages table)

**Email-Related**:
- `delivery_email` - Recipient address (from Agency)
- `origin_email` - Visitor's email (for reply-to)
- `delivery_success` - Boolean success flag
- `delivered_at` - Delivery timestamp
- `delivery_error` - Error message if failed
- `url` - Referrer URL
- `host` - Request host
- `origin_ip` - Visitor IP
- `user_agent` - Browser info
- `locale` - Language of inquiry

**Tenant ID**:
- `website_id` - Which website/tenant this message belongs to

### Sending Entry Points

1. **General Contact Form**
   - Controller: `Pwb::ContactUsController#contact_us_ajax`
   - Mailer: `EnquiryMailer.general_enquiry_targeting_agency`
   - Route: POST /pwb/contact_us_ajax

2. **Property Inquiry (REST)**
   - Controller: `Pwb::PropsController#request_property_info_ajax`
   - Mailer: `EnquiryMailer.property_enquiry_targeting_agency`
   - Route: POST /pwb/props/:id/request_property_info_ajax

3. **Property Inquiry (GraphQL)**
   - Mutation: `SubmitListingEnquiry`
   - Mailer: `Pwb::EnquiryMailer.property_enquiry_targeting_agency`
   - Endpoint: POST /graphql

### Testing

**Preview Emails**:
```bash
http://localhost:3000/rails/mailers/pwb/enquiry_mailer
```

**Specs**:
```bash
rspec spec/mailers/pwb/enquiry_mailer_spec.rb
```

**Test Methods**:
- `EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_now`
- `EnquiryMailer.property_enquiry_targeting_agency(contact, message, prop).deliver_now`

### Email Variables Available in Templates

**@contact** - Contact object
- `first_name`
- `primary_email` (also used as `primary_email`)
- `primary_phone_number`

**@message** - Message object
- `created_at`
- `content` - Message body
- `title` - Subject
- `origin_email` - Visitor email
- `delivery_email` - Recipient
- `url` - Referrer URL

**@property** - Property object (property inquiry only)
- `title`
- `description`

### I18n Keys

```
mailers.received_on
mailers.from
mailers.phone
mailers.message
mailers.property
mailers.general_enquiry_targeting_agency.title
mailers.property_enquiry_targeting_agency.title
```

### Troubleshooting

**Emails not sending?**
1. Check `SMTP_ADDRESS` is set
2. Check credentials: `SMTP_USERNAME`, `SMTP_PASSWORD`
3. Check delivery email configured: `Agency.email_for_*_contact_form`
4. Check `DEFAULT_FROM_EMAIL` if custom sender needed
5. Review Solid Queue jobs (may be pending/failed)
6. Check `pwb_messages.delivery_error` for error details
7. View Rails logs: `[EnquiryMailer]` entries

**Emails going to wrong address?**
1. Check `current_agency.email_for_*_contact_form` is configured
2. Check which website/agency is being used in request
3. Review `Message.delivery_email` value

**Emails not branded?**
1. Currently: NOT supported per-website
2. All websites use same template and content
3. Only change: Recipient email via Agency

## File Locations Reference

```
/app/mailers/pwb/
  ├── application_mailer.rb
  └── enquiry_mailer.rb

/app/views/pwb/mailers/
  ├── general_enquiry_targeting_agency.html.erb
  └── property_enquiry_targeting_agency.html.erb

/app/views/layouts/
  └── mailer.html.erb

/config/environments/
  ├── production.rb (SMTP config)
  ├── development.rb (email settings)
  └── test.rb (test delivery method)

/config/initializers/
  ├── devise.rb (Devise email)
  └── amazon_ses.rb (SES integration)

/spec/mailers/
  ├── pwb/enquiry_mailer_spec.rb
  └── previews/pwb/enquiry_mailer_preview.rb
```

## Architecture Notes

- **Tenant Scoped**: Message.website_id identifies tenant
- **Async**: Delivered via Solid Queue job adapter
- **Error Tracked**: Errors logged on Message record
- **Email Confirmed**: Tracking fields (delivery_success, delivered_at, delivery_error)
- **Multi-Provider**: Works with any SMTP provider
- **SES Ready**: Built-in AWS SES support via Pwb::SES module

## What's NOT Supported (Yet)

- Per-website email template customization
- Admin UI for template editing
- HTML/CSS email optimization
- Plain text email versions
- Website branding in emails
- Custom inquiry fields in emails
- Email analytics/tracking
- Email scheduling
- Template preview interface
- Email frequency controls
