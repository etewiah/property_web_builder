# Signup API Reference

Quick reference for all signup endpoints and their contracts.

---

## Endpoints

### Step 1: Email Capture

#### GET /signup

Display email capture form.

**Response:** HTML page
**No parameters**

---

#### POST /signup/start

Create lead user and reserve subdomain.

**Parameters:**
```ruby
{
  email: "user@example.com"  # Required, must be valid email format
}
```

**Success Response (302 Redirect):**
- Redirects to `/signup/configure`
- Sets session:
  - `session[:signup_user_id]` = User ID
  - `session[:signup_subdomain]` = Subdomain name (e.g., "sunny-meadow-42")

**Error Responses:**
```ruby
# Invalid email format
{
  status: 400,
  message: "Please enter a valid email address",
  html: form re-render with error flash
}

# Email already in use
{
  status: 422,
  message: "An account with this email already exists",
  html: form re-render with error flash
}

# Subdomain pool empty
{
  status: 503,
  message: "We're setting up new subdomains. Please try again in a few minutes, or contact support.",
  html: form re-render with error flash
}
```

**Session Duration:** User must complete Step 2 within 10 minutes (subdomain reservation expiry)

---

### Step 2: Site Configuration

#### GET /signup/configure

Display site configuration form.

**Prerequisites:**
- Must have completed Step 1 (`session[:signup_user_id]` must exist)

**Response:** HTML page

**Page Data:**
```erb
@step = 2
@suggested_subdomain = "sunny-meadow-42"  # From session or newly generated
@site_types = ["residential", "commercial", "vacation_rental"]
```

---

#### POST /signup/configure

Save site configuration and create website.

**Parameters:**
```ruby
{
  subdomain: "my-site",        # Custom subdomain, required
  site_type: "residential"     # One of: residential, commercial, vacation_rental
}
```

**Validation Rules:**
- Subdomain: 3-40 chars, lowercase letters/numbers/hyphens, no leading/trailing hyphens
- Site type: Must be in allowed list
- Subdomain must not be reserved by another email or already taken

**Success Response (302 Redirect):**
- Redirects to `/signup/provisioning`
- Sets session:
  - `session[:signup_website_id]` = Website ID
  
**Created Resources:**
```ruby
Website.create!(
  subdomain: "my-site",
  site_type: "residential",
  provisioning_state: "subdomain_allocated",
  seed_pack_name: "base",
  theme_name: "bristol"
)

UserMembership.create!(
  user_id: session[:signup_user_id],
  website_id: website.id,
  role: "owner",
  active: true
)

Subdomain.where(name: "my-site").first.allocate!(website)
```

**Error Responses:**
```ruby
# Subdomain already taken
{
  status: 422,
  message: "Subdomain is already taken",
  html: form re-render
}

# Invalid subdomain format
{
  status: 422,
  message: "Subdomain can only contain lowercase letters, numbers, and hyphens",
  html: form re-render
}

# Invalid site type
{
  status: 422,
  message: "Invalid site type. Choose from: residential, commercial, vacation_rental",
  html: form re-render
}

# User session expired
{
  status: 401,
  message: "Please start by entering your email",
  redirect: "/signup"
}
```

---

### Step 3: Provisioning

#### GET /signup/provisioning

Display provisioning progress page.

**Prerequisites:**
- Must have completed Step 2 (`session[:signup_website_id]` must exist)

**Response:** HTML page with JavaScript polling

**Page Data:**
```erb
@step = 3
@website = Website.find_by(id: session[:signup_website_id])
```

**JavaScript Behavior:**
1. On page load, checks if website is already `live?`
2. If live, redirects to `/signup/complete`
3. If provisioning, calls `startProvisioning()` which POSTs to `/signup/provision`
4. Polls status every 1-2 seconds via `GET /signup/status`
5. Updates progress bar and step indicators in real-time

---

#### POST /signup/provision

Trigger website provisioning (synchronous, will be async).

**Format:** JSON API

**Headers Required:**
```
X-CSRF-Token: <csrf_token>
Content-Type: application/json
```

**Body:** Empty (uses session for context)

**Success Response:**
```json
{
  "success": true,
  "status": "live",
  "progress": 100,
  "message": "Your website is live!",
  "website_id": 123
}
```

**Intermediate Response (if not yet live):**
```json
{
  "success": true,
  "status": "seeding",
  "progress": 70,
  "message": "Adding sample properties...",
  "website_id": 123
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Provisioning failed: Database connection timeout",
  "status": "failed",
  "progress": 45,
  "website_id": 123
}
```

**Status Values:**
- `pending` (0%)
- `subdomain_allocated` (20%)
- `configuring` (40%)
- `seeding` (70%)
- `ready` (95%)
- `live` (100%)
- `failed` (varies)

**Backend Operations:**
```ruby
# State transitions
website.start_configuring!         # pending → configuring
website.start_seeding!             # configuring → seeding
website.mark_ready!                # seeding → ready
website.go_live!                   # ready → live

# Configuration
configure_website_defaults(website)
# Sets: theme_name, default_client_locale, supported_locales

# Seeding
Pwb::Seeder.seed_for_website(website)
# Creates: Agency, Links, Sample Properties, Field Keys

# User activation
owner.activate! if owner.may_activate?
# Transitions: lead/onboarding → active
```

**Failure Handling:**
```ruby
# On error:
website.fail_provisioning!(error_message)
# Updates: provisioning_state = 'failed', provisioning_error = message
# User receives error with "Retry" button
```

---

#### GET /signup/status

Poll provisioning status (called by JavaScript polling).

**Format:** JSON API

**Parameters:** None (uses session for context)

**Success Response:**
```json
{
  "success": true,
  "status": "seeding",
  "progress": 70,
  "message": "Adding sample properties...",
  "complete": false,
  "website_id": 123
}
```

**Complete Response:**
```json
{
  "success": true,
  "status": "live",
  "progress": 100,
  "message": "Your website is live!",
  "complete": true,
  "website_id": 123
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Website not found",
  "website_id": 123
}
```

---

### Step 4: Completion

#### GET /signup/complete

Display completion page with next steps.

**Prerequisites:**
- Website must be `live?`
- User must be `active?`

**Response:** HTML page

**Page Data:**
```erb
@step = 4
@website = Website.find_by(id: session[:signup_website_id])
@user = @current_signup_user  # From session
```

**Website URLs Shown:**
- Public site: `https://my-site.propertywebbuilder.com`
- Admin dashboard: `https://my-site.propertywebbuilder.com/site_admin`

**Session Cleanup:**
```ruby
session.delete(:signup_user_id)
session.delete(:signup_subdomain)
session.delete(:signup_website_id)
```

---

## Helper Endpoints

### GET /signup/check_subdomain

Check if a subdomain is available.

**Format:** JSON API

**Parameters:**
```ruby
{
  name: "my-site"  # Subdomain to check
}
```

**Success Response:**
```json
{
  "available": true,
  "normalized": "my-site",
  "errors": []
}
```

**Taken Response:**
```json
{
  "available": false,
  "normalized": "my-site",
  "errors": ["is already taken"]
}
```

**Invalid Format Response:**
```json
{
  "available": false,
  "normalized": "my-site",
  "errors": [
    "must be at least 3 characters",
    "can only contain lowercase letters, numbers, and hyphens"
  ]
}
```

**Reserved Name Response:**
```json
{
  "available": false,
  "normalized": "admin",
  "errors": ["is reserved and cannot be used"]
}
```

**Validation Rules Applied:**
- Format: `[a-z0-9]([a-z0-9\-]*[a-z0-9])?`
- Length: 3-40 characters
- Not in reserved list: www, api, admin, app, mail, ftp, etc.
- Not already in use in Website or Subdomain tables

---

### GET /signup/suggest_subdomain

Get a random available subdomain suggestion.

**Format:** JSON API

**Parameters:** None

**Response:**
```json
{
  "subdomain": "sunny-meadow-42"
}
```

**Generation Rules:**
- Format: `adjective-noun-number`
- Examples: "crystal-peak-17", "golden-river-89", "swift-stream-25"
- Always unique (checked against existing databases)
- Always available (from available pool)

---

## Session Management

### Session Variables

```ruby
# Step 1
session[:signup_user_id]     # Integer, User ID
session[:signup_subdomain]   # String, Subdomain name

# Step 2
session[:signup_website_id]  # Integer, Website ID

# Cleared in Step 4
```

### Session Duration

- Overall signup must complete within ~2 hours (Rails default session timeout)
- Subdomain reservation lasts 10 minutes
- After Step 1 completion, subdomain expires if Step 2 not completed within 10 min
- If reservation expires, Step 2 can still proceed with new subdomain

---

## Error Codes

| Code | Meaning | Cause | Recovery |
|------|---------|-------|----------|
| 400 | Bad Request | Invalid email format | User corrects input |
| 401 | Unauthorized | Missing session | User restarts from Step 1 |
| 404 | Not Found | Website/user doesn't exist | Session expired, restart |
| 422 | Unprocessable Entity | Validation failed | User corrects input |
| 500 | Server Error | Database/system error | Retry, contact support |
| 503 | Service Unavailable | Subdomain pool exhausted | Try again later |

---

## Rate Limiting (Recommended)

For production deployment, implement rate limiting:

```ruby
# Per IP
GET /signup - unlimited (show form)
POST /signup/start - 10 requests per hour per IP
GET /signup/configure - unlimited
POST /signup/configure - 20 requests per hour per IP

# Per email
POST /signup/start - 5 requests per hour per email

# Per website
POST /signup/provision - 10 requests per hour per website_id
GET /signup/status - 60 requests per minute per website_id

# Per session
GET /signup/check_subdomain - 30 requests per minute per session
GET /signup/suggest_subdomain - 20 requests per minute per session
```

---

## Example Flows

### Successful Signup

```
1. GET /signup
   → Display email form

2. POST /signup/start
   → email: "alice@example.com"
   → Creates User (lead state)
   → Reserves "sunny-meadow-42"
   → Sets session[:signup_user_id] = 123
   → Sets session[:signup_subdomain] = "sunny-meadow-42"
   → Redirects to /signup/configure

3. GET /signup/configure
   → Display config form
   → @suggested_subdomain = "sunny-meadow-42"

4. [User types "my-site" and selects "residential"]

5. POST /signup/configure
   → subdomain: "my-site"
   → site_type: "residential"
   → Creates Website (subdomain_allocated state)
   → Creates UserMembership (owner)
   → Allocates subdomain
   → Sets session[:signup_website_id] = 456
   → Redirects to /signup/provisioning

6. GET /signup/provisioning
   → Display progress UI
   → JavaScript calls POST /signup/provision

7. POST /signup/provision (JSON)
   → Updates Website states: configuring → seeding → ready → live
   → Seeds: Agency, Links, 6 Sample Properties
   → Activates User (lead → active)
   → Returns: {"success": true, "status": "live", "progress": 100}

8. JavaScript redirects to /signup/complete

9. GET /signup/complete
   → Display success page
   → Clear session
   → Show website URL and next steps
```

### Failed Subdomain Check

```
1. User on Step 2 (/signup/configure)
2. Enters subdomain: "admin"
3. JavaScript calls GET /signup/check_subdomain?name=admin
4. Returns: {
     "available": false,
     "errors": ["is reserved and cannot be used"]
   }
5. UI shows red X next to input
6. User corrects to "admin-site"
7. JavaScript calls GET /signup/check_subdomain?name=admin-site
8. Returns: {"available": true, "errors": []}
9. UI shows green checkmark
10. User submits form
```

### Retry After Failure

```
1. POST /signup/provision starts provisioning
2. During seeding, database timeout occurs
3. Returns: {"success": false, "error": "Database timeout", "status": "seeding", "progress": 70}
4. UI shows error message with "Retry" button
5. User clicks "Retry"
6. POST /signup/provision called again
7. Website still in "seeding" state
8. Provisioning continues/restarts from previous state
9. Eventually succeeds
```

---

## Testing Examples

### cURL Examples

```bash
# Step 1: Start signup
curl -X POST http://localhost:3000/signup/start \
  -d "email=test@example.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -c cookies.txt

# Step 2: Configure site
curl -X POST http://localhost:3000/signup/configure \
  -d "subdomain=my-site&site_type=residential" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -b cookies.txt

# Step 3: Trigger provisioning (JSON)
curl -X POST http://localhost:3000/signup/provision \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: $(cat csrf_token.txt)" \
  -b cookies.txt

# Check status
curl -X GET http://localhost:3000/signup/status \
  -H "Content-Type: application/json" \
  -b cookies.txt

# Check subdomain availability
curl -X GET "http://localhost:3000/signup/check_subdomain?name=my-site" \
  -H "Content-Type: application/json" \
  -b cookies.txt
```

### Ruby Examples

```ruby
# Programmatic signup (e.g., for tests)
service = Pwb::ProvisioningService.new

# Step 1
result = service.start_signup(email: 'test@example.com')
user = result[:user]
subdomain = result[:subdomain]

# Step 2
result = service.configure_site(
  user: user,
  subdomain_name: 'my-site',
  site_type: 'residential'
)
website = result[:website]

# Step 3
result = service.provision_website(website: website)
website.reload
puts website.provisioning_state  # "live"
puts user.reload.onboarding_state  # "active"
```

