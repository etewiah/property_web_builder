# Quick Reference Card - Authentication & Signup

**One-page cheat sheet for PropertyWebBuilder auth system**

---

## Signup Flow (4 Steps)

| Step | Endpoint | What Happens | Token Used |
|------|----------|--------------|-----------|
| 1 | `POST /api/signup/start` | Create user, reserve subdomain | Creates `signup_token` |
| 2 | `POST /api/signup/configure` | Create website, add owner role | Uses `signup_token` |
| 3 | `POST /api/signup/provision` | Provision website, run seeds | Uses `signup_token` |
| 4 | `GET /api/signup/status` | Poll provisioning progress | Uses `signup_token` |

**Key Pattern**: Token-based, stateless tracking (works across domains/APIs)

---

## Authentication Methods

| Method | How It Works | Use Case |
|--------|-------------|----------|
| **Devise (Email/Password)** | Traditional Rails auth with password hash | Main login method |
| **Magic Link** | Email token → click link → auto-login | Passwordless (NEW) |
| **Firebase** | Firebase UI → JWT token → Rails verify | Social login option |
| **Password Reset** | Devise `:recoverable` module | Forgotten password |

---

## User States (AASM)

```
lead → registered → email_verified → onboarding → active
                                          ↓
                                   (4 steps tracked)
                                    1. Email ✓
                                    2. Subdomain
                                    3. Site Type
                                    4. Complete
```

---

## Website States (AASM)

```
pending (0%)
  ↓ [has_owner?]
owner_assigned (15%)
  ↓ [has_agency?]
agency_created (30%)
  ↓ [has_links? >= 3]
links_created (45%)
  ↓ [has_field_keys? >= 5]
field_keys_created (60%)
  ↓ [provisioning_complete?]
properties_seeded (80%)
  ↓ [provisioning_complete?]
ready (95%)
  ↓ [can_go_live?]
live (100%) ✓ Accessible
```

---

## Key Models

### User
- `email` - Unique identifier
- `website_id` - Primary website (legacy)
- `onboarding_state` - Current state (lead|registered|...)
- `signup_token` - For multi-step signup
- `magic_link_token` - For passwordless login (NEW)

**Relationships**:
```ruby
has_many :websites, through: :user_memberships
has_many :user_memberships
```

### Website
- `subdomain` - Unique tenant identifier
- `custom_domain` - Optional custom domain
- `site_type` - residential | commercial | vacation_rental
- `provisioning_state` - Current state (pending|live|...)

**Relationships**:
```ruby
has_many :user_memberships
has_many :members, through: :user_memberships, source: :user
```

### UserMembership
- `user_id` + `website_id` - Unique pair
- `role` - owner | admin | member | viewer
- `active` - Boolean flag

---

## Access Control Quick Decision Tree

```
Is user signed in?
├─ NO  → Redirect to login
└─ YES → Can user access this website?
        ├─ user.website_id == current_website.id?  → YES
        ├─ user.user_memberships.active.exists?(website)?  → YES
        ├─ user.firebase_uid.present?  → YES
        └─ ELSE  → NO → Show error
```

---

## Common Tasks

### Sign in user after login
```ruby
sign_in(user)  # Devise helper
redirect_to authenticated_root_path
```

### Check if user can access website
```ruby
user.can_access_website?(website)  # Returns boolean
user.role_for(website)  # Returns role or nil
```

### Grant access to website
```ruby
UserMembershipService.grant_access(
  user: user,
  website: website,
  role: 'member'
)
```

### Revoke access from website
```ruby
UserMembershipService.revoke_access(
  user: user,
  website: website
)
```

### Generate magic link
```ruby
token = SecureRandom.urlsafe_base64(32)
user.update_columns(
  magic_link_token: token,
  magic_link_expires_at: 24.hours.from_now
)
url = magic_login_url(token: token)
```

### Verify magic link
```ruby
user = User.find_by(magic_link_token: token)
return nil unless user
return nil if user.magic_link_expires_at < Time.current
user
```

### Log auth event
```ruby
Pwb::AuthAuditLog.log_login_success(
  user: user,
  request: request,
  website: current_website
)
```

---

## File Locations (Essential)

```
Auth Models:
  app/models/pwb/user.rb
  app/models/pwb/user_membership.rb
  app/models/pwb/website.rb
  app/models/pwb/current.rb

Auth Services:
  app/services/pwb/signup_api_service.rb
  app/services/pwb/provisioning_service.rb
  app/services/pwb/user_membership_service.rb
  app/services/pwb/firebase_auth_service.rb

Controllers:
  app/controllers/api/signup/signups_controller.rb
  app/controllers/pwb/auth_controller.rb
  app/controllers/api_public/v1/auth_controller.rb

Config:
  config/initializers/devise.rb
  config/initializers/auth_audit_hooks.rb

Migrations:
  db/migrate/*add_signup_token_to_users.rb
  db/migrate/*add_magic_link_token_to_users.rb (NEW)
```

---

## Configuration

### Devise (in initializer)
```ruby
config.timeout_in = 30.minutes         # Session timeout
config.lock_strategy = :failed_attempts # Lockout
config.maximum_attempts = 5            # Failed attempts
config.unlock_in = 1.hour              # Auto-unlock
```

### Firebase (in initializer)
```ruby
firebase_id_token.configure do |config|
  config.google_api_client = client
end
```

### Signup Token Expiry (in service)
```ruby
TOKEN_EXPIRY = 24.hours
user.update_columns(signup_token_expires_at: TOKEN_EXPIRY.from_now)
```

---

## Database Indexes

```sql
-- Critical indexes for performance
INDEX pwb_users(email)
INDEX pwb_users(signup_token)
INDEX pwb_users(magic_link_token)
INDEX pwb_websites(subdomain)
INDEX pwb_websites(custom_domain)
INDEX pwb_user_memberships(user_id, website_id) UNIQUE
INDEX pwb_auth_audit_logs(user_id, created_at DESC)
```

---

## Devise Routes (Auto-generated)

```
POST   /users/sign_in
DELETE /users/sign_out
POST   /users/sign_up
POST   /users/password (forgot password)
PATCH  /users/password (reset password)
GET    /users/edit
PATCH  /users
```

---

## API Endpoints (Signup)

```
POST   /api/signup/start              # Step 1: Email
POST   /api/signup/configure          # Step 2: Config
POST   /api/signup/provision          # Step 3: Provision
GET    /api/signup/status             # Check status
GET    /api/signup/check_subdomain    # Validate subdomain
GET    /api/signup/suggest_subdomain  # Get suggestion
GET    /api/signup/site_types         # List site types
GET    /api/signup/lookup_subdomain   # Find by email
```

---

## Testing Checklist

- [ ] Signup flow (all 4 steps)
- [ ] Email/password login
- [ ] Magic link generation
- [ ] Magic link expiry
- [ ] Multi-website access
- [ ] Role permissions
- [ ] Website provisioning guards
- [ ] Audit logging
- [ ] Firebase integration
- [ ] Session timeout

---

## Security Checklist

- [ ] HTTPS in production
- [ ] Password hashing (bcrypt)
- [ ] Account lockout enabled
- [ ] Audit logging enabled
- [ ] CSRF protection
- [ ] Session timeout
- [ ] No sensitive data in logs
- [ ] Rate limiting on login (optional)
- [ ] Magic link one-time use
- [ ] Token expiry enforced

---

## Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "invalid_website" | User can't access this website | Check membership exists for `current_website` |
| "signup_token invalid" | Token expired or wrong | Generate new token (24-hour expiry) |
| "User already exists" | Email already has website | Can't start new signup with same email |
| "Subdomain taken" | Already in use | Choose different subdomain |
| "No owner membership" | Provisioning guard failed | Create owner membership before transition |

---

## Performance Tips

1. **Query optimization**: Use `.includes(:websites)` for multi-website loads
2. **Token lookup**: Index on `signup_token` and `magic_link_token` (already done)
3. **Audit logs**: Archive old logs periodically
4. **Current context**: Uses ThreadLocal (fast, no DB hit)
5. **Membership checks**: Add cache if checking same user multiple times

---

## Monitoring/Alerting

Watch these in production:

1. **Failed logins** - May indicate brute force attacks
2. **Account lockouts** - May indicate compromised passwords
3. **Provisioning failures** - May indicate system issues
4. **Session timeouts** - May indicate user frustration
5. **Magic link usage** - Track adoption

---

## Links to Full Documentation

- **Complete Analysis**: `docs/claude_thoughts/AUTHENTICATION_SIGNUP_ANALYSIS.md`
- **Flow Diagrams**: `docs/claude_thoughts/AUTHENTICATION_FLOW_DIAGRAMS.md`
- **Magic Links Guide**: `docs/claude_thoughts/MAGIC_LINKS_IMPLEMENTATION_GUIDE.md`
- **Executive Summary**: `docs/claude_thoughts/ANALYSIS_SUMMARY.md`

---

**Last Updated**: 2025-12-14  
**Version**: 1.0  
**Status**: Production-Ready
