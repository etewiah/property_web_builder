# Signup Flow - Quick Start Guide

A condensed reference for the signup system architecture and key operations.

---

## System Architecture

```
┌──────────────────────────────────────────────┐
│ SignupController (8 actions)                 │
├──────────────────────────────────────────────┤
│ - new/start (email capture)                  │
│ - configure/save_configuration (site setup)  │
│ - provisioning/provision (deployment)        │
│ - status (polling endpoint)                  │
│ - complete (success page)                    │
│ - check_subdomain (validation)               │
│ - suggest_subdomain (generation)             │
└────────────────┬─────────────────────────────┘
                 │
                 v
┌──────────────────────────────────────────────┐
│ ProvisioningService (orchestrator)           │
├──────────────────────────────────────────────┤
│ - start_signup(email)                        │
│ - configure_site(user, subdomain, type)      │
│ - provision_website(website)                 │
│ - retry_provisioning(website)                │
└────────────────┬─────────────────────────────┘
                 │
        ┌────────┴────────┬────────────┐
        v                 v            v
┌──────────────┐ ┌────────────────┐ ┌──────────┐
│ SubdomainGen │ │ Seeder         │ │ Models   │
├──────────────┤ ├────────────────┤ ├──────────┤
│ Generate     │ │ Agency         │ │ User     │
│ Validate     │ │ Properties     │ │ Website  │
│ Reserve      │ │ Links          │ │ Subdomain│
│ Pool mgmt    │ │ Field Keys     │ │ Member   │
└──────────────┘ └────────────────┘ └──────────┘
```

---

## The 4 Steps

| Step | User Action | System Action | Result |
|------|-------------|---------------|--------|
| 1 | Enter email | Create User (lead), Reserve Subdomain | session[:signup_user_id] |
| 2 | Choose subdomain & type | Create Website, UserMembership | session[:signup_website_id] |
| 3 | Click "Provision" | Seed data, Deploy, Activate User | Website.live? = true |
| 4 | View success page | Clear session | User.active? = true |

---

## Key Classes

### SignupController
**File:** `app/controllers/pwb/signup_controller.rb`  
**Purpose:** HTTP request handling, session management, view rendering

```ruby
# Key methods
def start           # POST /signup/start
def save_configuration   # POST /signup/configure
def provision       # POST /signup/provision
def status          # GET /signup/status (JSON polling)
```

### ProvisioningService
**File:** `app/services/pwb/provisioning_service.rb`  
**Purpose:** Business logic orchestration, state transitions

```ruby
# Public API
service.start_signup(email: "user@example.com")
service.configure_site(user:, subdomain_name:, site_type:)
service.provision_website(website:)
service.retry_provisioning(website:)
```

### Models with State Machines

**User**
```
lead → onboarding → active
     → churned (if abandoned)
```

**Website**
```
pending → subdomain_allocated → configuring → seeding → ready → live
                                                               → failed
```

**Subdomain**
```
available → reserved → allocated → released → available
```

---

## Session Data

```ruby
# Step 1
session[:signup_user_id] = 123

# Step 2
session[:signup_website_id] = 456

# Step 3 - cleared after
session.delete(:signup_user_id)
session.delete(:signup_website_id)
```

---

## Database Operations Summary

### Step 1: Email Capture
```sql
INSERT INTO pwb_users (email, onboarding_state) VALUES (...)
UPDATE pwb_subdomains SET aasm_state='reserved', reserved_by_email=... WHERE ...
```

### Step 2: Configuration
```sql
INSERT INTO pwb_websites (subdomain, site_type, provisioning_state) VALUES (...)
INSERT INTO pwb_user_memberships (user_id, website_id, role) VALUES (...)
UPDATE pwb_subdomains SET aasm_state='allocated', website_id=... WHERE ...
```

### Step 3: Provisioning
```sql
UPDATE pwb_websites SET provisioning_state='configuring' WHERE ...
UPDATE pwb_websites SET provisioning_state='seeding' WHERE ...
  -- Bulk inserts for seeded data
INSERT INTO pwb_agencies (...) VALUES (...)
INSERT INTO pwb_realty_assets (...) VALUES (...)  -- x6
INSERT INTO pwb_links (...) VALUES (...)
UPDATE pwb_websites SET provisioning_state='live', provisioning_completed_at=NOW() WHERE ...
UPDATE pwb_users SET onboarding_state='active' WHERE ...
```

---

## Critical Operations

### Reserve a Subdomain
```ruby
# Finds random available from pool, marks as reserved for 10 minutes
subdomain = Subdomain.reserve_for_email(email, duration: 10.minutes)
```

### Validate Subdomain
```ruby
# Checks format, length, reserved names, uniqueness
result = SubdomainGenerator.validate_custom_name(name, reserved_by_email: email)
# Returns: {valid: bool, normalized: string, errors: []}
```

### Seed Sample Data
```ruby
# Creates 6 sample properties with photos, agency, links
Pwb::Seeder.seed_for_website(website)
```

### Activate User
```ruby
# Transitions user from lead/onboarding to active
user.activate! if user.may_activate?
```

---

## Error Handling

| Scenario | Error | Solution |
|----------|-------|----------|
| Invalid email | Regex check fails | User re-enters email |
| Email in use | User.exists? | Show "already exists" message |
| Subdomain taken | Validation fails | Suggest another |
| Pool empty | No available subdomains | Contact support |
| Provisioning fails | Exception in seeding | Retry button |

---

## Routes

```ruby
get    "/signup"                  # Show email form
post   "/signup/start"            # Create user + reserve subdomain
get    "/signup/configure"        # Show config form
post   "/signup/configure"        # Create website + membership
get    "/signup/provisioning"     # Show progress page
post   "/signup/provision"        # Trigger seeding (JSON)
get    "/signup/status"           # Poll status (JSON)
get    "/signup/complete"         # Show success page
get    "/signup/check_subdomain"  # Validate subdomain (JSON)
get    "/signup/suggest_subdomain"# Generate suggestion (JSON)
```

---

## API Responses (JSON)

### POST /signup/provision
```json
{
  "success": true,
  "status": "live",
  "progress": 100,
  "message": "Your website is live!"
}
```

### GET /signup/status
```json
{
  "success": true,
  "status": "seeding",
  "progress": 70,
  "message": "Adding sample properties...",
  "complete": false
}
```

### GET /signup/check_subdomain
```json
{
  "available": true,
  "normalized": "my-site",
  "errors": []
}
```

---

## Testing Signup Locally

```bash
# Start Rails server
rails s -b 0.0.0.0 -p 3000

# In browser: http://localhost:3000/signup

# Or programmatically
```

```ruby
service = Pwb::ProvisioningService.new

# Step 1
user = service.start_signup(email: 'test@example.com')[:user]

# Step 2
website = service.configure_site(
  user: user,
  subdomain_name: 'test-site',
  site_type: 'residential'
)[:website]

# Step 3
service.provision_website(website: website)

# Verify
website.reload
puts website.live?            # true
puts user.reload.active?      # true
```

---

## Subdomain Pool Management

```bash
# Check pool health
rails c
> Subdomain.group(:aasm_state).count
# {available: 900, allocated: 100}

# Repopulate pool
rails pwb:provisioning:populate_subdomains COUNT=1000

# Clean up expired reservations
Subdomain.release_expired!
```

---

## Performance Metrics

- **Step 1:** ~100ms (user + subdomain creation)
- **Step 2:** ~200ms (website + membership creation)
- **Step 3:** ~30-60s (seeding, currently synchronous)
- **Overall:** ~35s average

**Bottleneck:** Step 3 provisioning (should be async)

---

## Common Issues & Fixes

### Issue: Subdomain pool empty
```
Error: "Subdomain pool is empty"
Fix: rails pwb:provisioning:populate_subdomains COUNT=1000
```

### Issue: Provisioning stuck
```
Check: Website.find(id).provisioning_state
Fix: website.fail_provisioning!("Manual failure")
     # Then retry
```

### Issue: User not marked active
```
Check: User.find(id).onboarding_state
Fix: user.activate! if user.may_activate?
```

### Issue: Session data missing
```
Check: session[:signup_user_id].present?
Fix: User restarts from /signup
```

---

## Debugging Commands

```ruby
# Find signup in progress
Pwb::User.where(onboarding_state: 'onboarding')

# Check website provisioning state
website = Pwb::Website.last
puts "Status: #{website.provisioning_state}"
puts "Progress: #{website.provisioning_progress}%"
puts "Message: #{website.provisioning_status_message}"

# Check subdomain allocation
subdomain = Pwb::Subdomain.find_by(name: 'my-site')
puts "Allocated: #{subdomain.allocated?}"
puts "Website: #{subdomain.website_id}"

# Retry failed provisioning
service = Pwb::ProvisioningService.new
result = service.retry_provisioning(website: website)
puts result.inspect
```

---

## Extracted Code Locations

| Component | File | Size | Purpose |
|-----------|------|------|---------|
| Controller | `app/controllers/pwb/signup_controller.rb` | 265 lines | HTTP handling |
| Service | `app/services/pwb/provisioning_service.rb` | 303 lines | Business logic |
| Generator | `app/services/pwb/subdomain_generator.rb` | 167 lines | Name generation |
| Seeder | `lib/pwb/seeder.rb` | 522 lines | Sample data |
| Views | `app/views/pwb/signup/*.erb` | 4 files | UI templates |
| Layout | `app/views/layouts/pwb/signup.html.erb` | 77 lines | Page structure |
| **Total** | | **~1.3K lines** | |

---

## Integration Points

1. **Pre-signup:** Populate subdomain pool via rake task
2. **During signup:** Use ProvisioningService API
3. **Post-signup:** 
   - Send password reset email
   - Trigger welcome email
   - Update user analytics
   - Initialize theme settings

---

## Monitoring Queries

```sql
-- Signup funnel
SELECT onboarding_state, COUNT(*) FROM pwb_users GROUP BY onboarding_state;

-- Website deployment status
SELECT provisioning_state, COUNT(*) FROM pwb_websites GROUP BY provisioning_state;

-- Subdomain pool health
SELECT aasm_state, COUNT(*) FROM pwb_subdomains GROUP BY aasm_state;

-- Failed provisioning
SELECT * FROM pwb_websites WHERE provisioning_state = 'failed' ORDER BY updated_at DESC;
```

---

## Key Takeaways

1. **4-Step Flow:** Email → Config → Provision → Complete
2. **Session-Based:** Uses Rails sessions to track progress
3. **State Machines:** User, Website, Subdomain all have state machines
4. **Orchestrated Service:** ProvisioningService handles all logic
5. **Synchronous Seeding:** Currently blocks, should be async
6. **Multi-tenant:** Each website is isolated tenant
7. **Extractable:** Well-separated concerns make extraction feasible
8. **Reliable:** Transaction-wrapped, with retry logic

---

## Next Steps

- [ ] Review [Signup Flow Documentation](./signup_flow.md) for detailed flow
- [ ] Check [API Reference](./signup_api_reference.md) for endpoint details
- [ ] Read [Extraction Guide](./signup_extraction_guide.md) for component isolation
- [ ] Run tests: `bundle exec rspec spec/services/pwb/provisioning_service_spec.rb`
- [ ] Try signup flow locally: `http://localhost:3000/signup`
- [ ] Inspect database: `rails dbconsole`
- [ ] Monitor logs: `tail -f log/development.log | grep Signup`

