# Priority Test Scenarios - Detailed Breakdown

## P1.1: Site Admin Dashboard Controller

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/dashboard_controller.rb`
**Test File:** `spec/requests/site_admin/dashboard_spec.rb`
**Estimated Tests:** 15
**Estimated Time:** 2 hours

### Test Scenarios

```gherkin
# Scenario 1: Dashboard loads with website statistics
Given a user with admin access
When they visit the site admin dashboard
Then they see statistics for:
  - Total properties (using Pwb::ListedProperty materialized view)
  - Total pages
  - Total contents
  - Total messages
  - Total contacts
And all numbers match actual database counts

# Scenario 2: Weekly activity stats
Given a website with various activity
When they view the dashboard
Then they see weekly stats for:
  - New messages this week
  - New contacts this week
  - New properties this week
And dates are calculated from Time.current.beginning_of_week

# Scenario 3: Unread messages count
Given messages with read=false
When they view dashboard
Then unread_messages_count is correct
And uses where(read: false) filter

# Scenario 4: Recent activity timeline
Given mixed activity across messages, properties, contacts
When they view dashboard
Then timeline shows last 10 items
And items sorted by created_at DESC
And includes type, icon, title, time, path for each
And paths are valid route helpers

# Scenario 5: Website health checklist
Given incomplete website setup
When they view dashboard
Then health checklist shows:
  - Agency profile complete: presence of company_name + email_primary
  - At least one property added
  - Theme configured: theme_name present
  - Custom domain configured: custom_domain present
  - Social media links (visible links with slug LIKE 'social_%')
  - SEO configured: default_seo_title OR default_meta_description
  - Logo uploaded: main_logo_url present
And percentage calculated as completed/total * 100
And routes provided for each incomplete item

# Scenario 6: Health checklist shows getting started
Given website health < 70% OR properties < 3
When they view dashboard
Then getting_started guide shown
Unless dismiss_getting_started cookie = 'true'

# Scenario 7: Subscription information displayed
Given an active subscription
When they view dashboard
Then they see:
  - Status (trialing/active/past_due/expired)
  - Plan display name
  - Plan formatted price
  - Trial days remaining (if trialing)
  - Trial ending soon flag (if within 3 days)
  - In good standing status
  - Current period end date
  - Property limit vs remaining
  - Enabled features list

# Scenario 8: Subscription missing (free mode)
Given website with no subscription
When they view dashboard
Then subscription_info is nil or omitted
And no subscription errors shown

# Scenario 9: Multi-tenancy isolation
Given user on website A
When they view dashboard
Then only see data for website A
Not data from website B
And this applies to all stats (properties, pages, messages, etc.)

# Scenario 10: Timestamp handling
Given properties created at various times
When viewing dashboard
Then times display correctly
And "recent" means last 5-24 hours
And dates formatted appropriately

# Scenario 11: Empty website
Given brand new website with no content
When they view dashboard
Then still shows page without errors
And all counts show 0
And health checklist shows 0% with all items incomplete

# Scenario 12: Large dataset
Given 10000+ properties, messages, contacts
When they view dashboard
Then page loads reasonably fast
And uses optimized queries (materialized view)
And pagination not needed for recent items

# Scenario 13: Status badge visibility
Given subscription in various states
When viewing dashboard
Then badge shows:
  - Trialing: "Trial" with days remaining
  - Active: "Active" with green badge
  - Past Due: "Past Due" with warning
  - Expired: "Expired" with error

# Scenario 14: Plan limits visualization
Given subscription with property limit 50
And 45 properties currently
When viewing dashboard
Then shows:
  - "45 / 50 properties used" or similar
  - 90% usage progress bar
  - Warning if near limit

# Scenario 15: Call to action
Given subscription trial ending in 2 days
When viewing dashboard
Then shows upgrade CTA
And includes link to billing or upgrade page
```

### Key Implementation Notes

1. **Stats Calculation:**
   ```ruby
   @stats = {
     total_properties: Pwb::ListedProperty.where(website_id: website_id).count,
     total_pages: Pwb::Page.where(website_id: website_id).count,
     # ... etc
   }
   ```

2. **Multi-tenancy Testing:**
   - Always set subdomain in test
   - Create data on multiple websites
   - Verify results only contain current website data

3. **Subscription Handling:**
   - Test both with and without subscription
   - Test both active and trial states
   - Mock subscription.plan relationship

4. **Timeline Building:**
   - Ensure proper sorting by created_at
   - Verify limit of 10 items
   - Check all message/property/contact data accessible

---

## P1.2: Contact Us Form Controller

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/contact_us_controller.rb`
**Test File:** `spec/requests/pwb/contact_us_spec.rb` or `spec/integration/contact_form_email_spec.rb`
**Estimated Tests:** 12
**Estimated Time:** 2.5 hours

### Test Scenarios

```gherkin
# Scenario 1: Contact form page loads
Given a public user
When they visit /contact-us
Then they see the contact form
And page title includes agency name
And map appears if show_contact_map = true

# Scenario 2: Form submission - valid data
Given a filled contact form with:
  - name: "John Smith"
  - email: "john@example.com"
  - phone: "+1 555-1234"
  - message: "Interested in properties"
When they submit
Then:
  - Contact record created with email
  - Message record created
  - HTTP status 200 or redirect to confirmation
  - Success message shown

# Scenario 3: Contact creation or find existing
Given contact with email john@example.com exists
When new submission from same email
Then:
  - Existing contact found (find_or_initialize_by)
  - Phone number updated
  - First name updated
  - Contact.count unchanged

# Scenario 4: Message creation
Given contact submitted form
When checking Message record
Then has:
  - title: from params[:contact][:subject]
  - content: from params[:contact][:message]
  - locale: from params[:contact][:locale]
  - url: from request.referer
  - host: from request.host
  - origin_ip: from request.ip
  - user_agent: from request.user_agent
  - website_id: current website
  - contact_id: associated contact

# Scenario 5: Email delivery
Given submission
When checking emails
Then:
  - EnquiryMailer.general_enquiry_targeting_agency called
  - Delivery email set to agency.email_for_general_contact_form
  - Email queued (deliver_later not immediate)

# Scenario 6: Auto-reply email
Given contact form submission
When checking emails
Then:
  - Auto-reply sent to visitor email
  - Subject "Thank you for contacting [agency]"
  - Body confirms message received

# Scenario 7: Push notification (ntfy)
Given website with ntfy_enabled = true
When form submitted
Then:
  - NtfyNotificationJob queued
  - Job receives website_id, type: :inquiry, message_id

# Scenario 8: Push notification disabled
Given website with ntfy_enabled = false
When form submitted
Then:
  - NtfyNotificationJob NOT queued

# Scenario 9: Validation errors - missing fields
Given submission with missing email
When submitting
Then:
  - Form re-rendered with error
  - Error message shown to user
  - No Contact/Message created
  - No email sent

# Scenario 10: Structured logging
Given submission
When form processed
Then StructuredLogger records:
  - website_id
  - contact email
  - subject
  - origin_ip
  - message for each stage (Processing, Validation, Success)
  - errors if validation fails

# Scenario 11: Error handling
Given invalid data causes exception
When submitting
Then:
  - Error caught gracefully
  - User sees: "There was an error. Please try again."
  - Exception logged with backtrace
  - No crash to user

# Scenario 12: Multi-tenancy isolation
Given two websites
When contact submitted on website A
Then:
  - Contact belongs to website A
  - Message belongs to website A
  - Email sent to website A's agency
  - No cross-contamination with website B
```

### Key Implementation Notes

1. **Delivery Email Logic:**
   ```ruby
   delivery_email = @current_agency.email_for_general_contact_form
   if delivery_email.blank?
     delivery_email = "no_delivery_email@propertywebbuilder.com"
     StructuredLogger.warn('[ContactForm] No delivery email configured', ...)
   end
   ```

2. **Request Metadata Capture:**
   ```ruby
   origin_ip: request.ip
   user_agent: request.user_agent
   host: request.host
   ```

3. **Email Mocking in Tests:**
   ```ruby
   expect {
     post "/contact-us", params: { ... }
   }.to change { ActionMailer::Base.deliveries.count }.by(2) # Main + Reply
   ```

4. **Job Enqueueing:**
   ```ruby
   expect {
     post "/contact-us", params: { ... }
   }.to have_enqueued_job(NtfyNotificationJob)
   ```

---

## P1.3: Setup Controller

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/pwb/setup_controller.rb`
**Test File:** `spec/requests/pwb/setup_spec.rb` or `spec/integration/setup_flow_spec.rb`
**Estimated Tests:** 10
**Estimated Time:** 2 hours

### Test Scenarios

```gherkin
# Scenario 1: Setup page shows seed packs
Given no website exists for subdomain
When they visit /setup
Then:
  - Available seed packs displayed
  - Each pack has name and description
  - Pack list not empty

# Scenario 2: Create website from seed pack
Given setup page with available packs
When they select "Brisbane" pack and submit
Then:
  - Website created with seed pack name
  - Website visible/live immediately
  - Seed pack applied to website
  - Redirect to website home

# Scenario 3: Invalid pack selection
Given setup form
When they submit without selecting pack
Then:
  - Error message: "Please select a seed pack"
  - Redirect back to setup page
  - No website created

# Scenario 4: Nonexistent pack
Given form with pack_name = 'fake-pack'
When submitting
Then:
  - Error: "Seed pack 'fake-pack' not found"
  - Redirect to setup
  - No website created

# Scenario 5: Theme from seed pack
Given seed pack with website.theme_name = 'brisbane'
When website created
Then:
  - website.theme_name set to 'brisbane'
  - Theme applied to site

# Scenario 6: Default theme if pack has no theme
Given seed pack without theme config
When website created
Then:
  - theme_name defaults to 'default'

# Scenario 7: Seed pack application
Given website created with pack
When checking data
Then:
  - pack.apply! called with website
  - Data created (properties, pages, content)
  - Pack not re-applied if website exists

# Scenario 8: Already setup prevention
Given website already exists for subdomain
When they visit /setup
Then:
  - Redirect to root_path (/)
  - Setup page not shown

# Scenario 9: Subdomain handling
Given setup with custom subdomain
When creating website
Then:
  - custom subdomain used
  - OR request.subdomain if empty

# Scenario 10: Error recovery
Given seed pack application fails
When website created
Then:
  - Website still created
  - Flash message: "Website created but seeding failed"
  - Redirect to website home
  - Error logged
  - User can manually seed or use defaults
```

### Key Implementation Notes

1. **Available Packs:**
   ```ruby
   @seed_packs = Pwb::SeedPack.available
   # Returns array of pack names/objects
   ```

2. **Seed Pack Finding:**
   ```ruby
   pack = Pwb::SeedPack.find(pack_name)
   # Raises Pwb::SeedPack::PackNotFoundError if not found
   ```

3. **Website Creation:**
   ```ruby
   website = Pwb::Website.new(
     subdomain: subdomain,
     provisioning_state: 'live',
     theme_name: pack.config.dig(:website, :theme_name) || 'default'
   )
   ```

4. **Already Setup Check:**
   ```ruby
   website = Pwb::Website.find_by_subdomain(request.subdomain)
   redirect_to root_path if website.present?
   ```

---

## P1.4: Analytics Controller

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/analytics_controller.rb`
**Test File:** `spec/requests/site_admin/analytics_spec.rb`
**Estimated Tests:** 12
**Estimated Time:** 2.5 hours

### Test Scenarios

```gherkin
# Scenario 1: Analytics not available - redirect
Given subscription without analytics feature
When they visit /site_admin/analytics
Then:
  - Redirect to site admin root
  - Flash alert: "Analytics available on paid plans"

# Scenario 2: Analytics available on paid plan
Given subscription with analytics feature
When they visit /site_admin/analytics
Then:
  - Page loads successfully
  - Analytics data displayed

# Scenario 3: No subscription (free mode)
Given website without subscription
When they visit /site_admin/analytics
Then:
  - Analytics allowed (no subscription = no restrictions)

# Scenario 4: Show action - overview
Given analytics enabled
When they visit /site_admin/analytics
Then they see:
  - Visits by day chart
  - Traffic by source (organic, direct, referral, social)
  - Device breakdown (mobile, desktop, tablet)

# Scenario 5: Traffic action
Given analytics enabled
When they visit /site_admin/analytics/traffic
Then they see:
  - Visits by day
  - Unique visitors by day
  - Traffic sources list
  - UTM campaigns
  - Geographic breakdown

# Scenario 6: Properties action
Given analytics enabled
When they visit /site_admin/analytics/properties
Then they see:
  - Top 20 properties by views
  - Property views by day
  - Top searches

# Scenario 7: Conversions action
Given analytics enabled
When they visit /site_admin/analytics/conversions
Then they see:
  - Inquiry funnel (visits -> property views -> inquiries)
  - Conversion rates for each funnel stage
  - Inquiries by day chart

# Scenario 8: Realtime action - HTML
Given analytics enabled
When they visit /site_admin/analytics/realtime
Then:
  - Active visitors count displayed
  - Recent pageviews listed

# Scenario 9: Realtime action - JSON
Given analytics enabled
When they visit /site_admin/analytics/realtime.json
Then:
  - JSON response: { active_visitors: N, recent_pageviews: [] }
  - Proper content-type header

# Scenario 10: Period filtering - 7 days
Given analytics with period = 7
When calculating data
Then:
  - Only last 7 days included
  - Uses (params[:period] || 30).to_i
  - Defaults to 30 if invalid

# Scenario 11: Valid period values
Given period parameter
When validating
Then only accepts: [7, 14, 30, 60, 90]
And defaults to 30 if other value

# Scenario 12: Multi-tenancy isolation
Given user on website A with analytics
When viewing analytics
Then:
  - Only see data for website A
  - Not website B data
  - All service calls scoped to current_website
```

### Key Implementation Notes

1. **Feature Check:**
   ```ruby
   def analytics_enabled?
     subscription = current_website.subscription
     return true if subscription.nil?
     subscription.plan&.features&.include?("analytics") ||
       subscription.plan&.features&.include?("basic_analytics")
   end
   ```

2. **Period Handling:**
   ```ruby
   @period = (params[:period] || 30).to_i
   @period = 30 unless [7, 14, 30, 60, 90].include?(@period)
   ```

3. **Service Usage:**
   ```ruby
   @analytics = Pwb::AnalyticsService.new(current_website, period: @period.days)
   ```

4. **Response Formats:**
   ```ruby
   respond_to do |format|
     format.html
     format.json { render json: { ... } }
   end
   ```

---

## P1.5: Email Templates Controller

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/email_templates_controller.rb`
**Test File:** `spec/requests/site_admin/email_templates_spec.rb`
**Estimated Tests:** 12
**Estimated Time:** 2.5 hours

### Test Scenarios

```gherkin
# Scenario 1: Templates index shows allowed templates
Given email templates feature
When visiting /site_admin/email_templates
Then:
  - Shows enquiry.general
  - Shows enquiry.property
  - Does NOT show: alerts, user emails
  - Shows which templates have customizations

# Scenario 2: New template form
Given visiting new template form with template_key=enquiry.general
When form loads
Then:
  - Pre-populated with default template
  - Subject shown: "New enquiry from {{ visitor_name }}"
  - Body HTML with HTML table
  - Description shown
  - Name: "General Enquiry"

# Scenario 3: Create custom template
Given submitting new template
When form completed with custom content
Then:
  - Template saved to database
  - template_key set correctly
  - subject saved
  - body_html saved
  - body_text generated from HTML
  - Redirect to show page

# Scenario 4: Invalid template key
Given accessing new with invalid key
When visiting /site_admin/email_templates/new?template_key=fake.template
Then:
  - Redirect to index
  - Alert: "Invalid template type"

# Scenario 5: Show custom template
Given custom template exists
When viewing /site_admin/email_templates/1
Then:
  - Display template name
  - Display subject
  - Display body_html
  - Show edit and delete buttons

# Scenario 6: Edit template
Given existing template
When visiting edit and changing subject
Then:
  - Changes saved
  - Redirect to show
  - Notice: "Email template updated"

# Scenario 7: Delete custom template
Given custom template exists
When deleting
Then:
  - Template deleted from database
  - Redirect to index
  - Notice: "Email template deleted. Default will now be used"
  - Subsequent renders use default

# Scenario 8: Preview custom template
Given custom template exists
When visiting preview
Then:
  - Shows rendered HTML
  - Shows rendered text
  - Variables substituted with sample data

# Scenario 9: Preview default template
Given no custom template
When visiting /site_admin/email_templates/preview_default?template_key=enquiry.general
Then:
  - Shows default template
  - Variables substituted with sample data
  - Render with sample_variables (visitor_name: "John Smith", etc.)

# Scenario 10: Sample variables generation
Given template with variables
When generating samples
Then:
  - visitor_name: "John Smith"
  - visitor_email: "john@example.com"
  - visitor_phone: "+1 555-123-4567"
  - message: "I am interested in learning more..."
  - property_title: "Beautiful 3 Bedroom House"
  - property_price: "$350,000"
  - etc. for all template keys

# Scenario 11: Liquid rendering in template
Given template subject: "Enquiry from {{ visitor_name }}"
When rendering with visitor_name: "Alice"
Then:
  - Subject becomes: "Enquiry from Alice"
  - HTML also processes variables
  - Text also processes variables

# Scenario 12: Only two template keys allowed
Given attempting to edit enquiry.general
When checking ALLOWED_TEMPLATE_KEYS
Then:
  - Only [enquiry.general, enquiry.property] allowed in site_admin
  - Other templates managed in tenant_admin
  - Access to other templates denied
```

### Key Implementation Notes

1. **Allowed Keys:**
   ```ruby
   ALLOWED_TEMPLATE_KEYS = %w[enquiry.general enquiry.property].freeze
   ```

2. **Default Content:**
   ```ruby
   Pwb::EmailTemplateRenderer.new(website: current_website, template_key: @template_key)
   defaults = renderer.default_template_content
   ```

3. **Sample Data:**
   ```ruby
   sample_data = {
     "website_name" => current_website&.company_display_name || "Your Company",
     "visitor_name" => "John Smith",
     # ... etc
   }
   ```

4. **Validation:**
   - Template key must be in ALLOWED_TEMPLATE_KEYS
   - Subject and body_html are required
   - Invalid keys return error

---

## Summary: First Week Focus

These 5 controllers represent the most critical gaps:

1. **Dashboard** (2 hours) - 15 tests - User interface main view
2. **Contact Form** (2.5 hours) - 12 tests - Lead generation
3. **Setup** (2 hours) - 10 tests - Customer onboarding
4. **Analytics** (2.5 hours) - 12 tests - Premium feature
5. **Email Templates** (2.5 hours) - 12 tests - Communications

**Total: 11.5 hours, 61 tests**

---

## Testing Best Practices for These Scenarios

### 1. Multi-Tenancy Testing
```ruby
let(:website_a) { create(:pwb_website, subdomain: 'website-a') }
let(:website_b) { create(:pwb_website, subdomain: 'website-b') }

# Test isolation
create_list(:pwb_prop, 5, website: website_a)
create_list(:pwb_prop, 10, website: website_b)

# User signs in for website A
@request.host = "#{website_a.subdomain}.example.com"
allow(Pwb::Current).to receive(:website).and_return(website_a)

# Verify only website A data visible
expect(response.body).to include("5") # Not 10 or 15
```

### 2. Email Testing
```ruby
# Verify email sent
expect {
  post "/contact-us", params: { contact: {...} }
}.to change { ActionMailer::Base.deliveries.count }.by(1)

# Check email content
last_email = ActionMailer::Base.deliveries.last
expect(last_email.to).to include("agency@example.com")
expect(last_email.subject).to include("New enquiry")
```

### 3. Job Enqueueing
```ruby
# Verify job queued
expect {
  post "/contact-us", params: { contact: {...} }
}.to have_enqueued_job(NtfyNotificationJob)
  .with(website.id, :inquiry, message.id)
```

### 4. Response Assertions
```ruby
# Status codes
expect(response).to have_http_status(:success) # 200
expect(response).to have_http_status(:unprocessable_entity) # 422
expect(response).to redirect_to(root_path)

# Content assertions
expect(response.body).to include("Dashboard")
expect(response.parsed_body["analytics"]).to be_present
```

### 5. Flash Messages
```ruby
expect(flash[:notice]).to include("created successfully")
expect(flash[:alert]).to include("not available")
```

---

## Files Created for Reference

1. **test_coverage_analysis.md** - Full detailed analysis
2. **test_gaps_quick_reference.md** - Quick lookup guide
3. **priority_test_scenarios.md** - This file with detailed scenarios

All files in: `/Users/etewiah/dev/sites-older/property_web_builder/docs/claude_thoughts/`
