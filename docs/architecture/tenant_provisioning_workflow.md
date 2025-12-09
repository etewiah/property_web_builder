# Tenant Provisioning Workflow

## Overview

This document describes the self-service tenant provisioning system that allows new users to sign up and create their own property website. The system uses AASM state machines to track progress through the signup and provisioning process.

## Architecture Components

### 1. State Machines

The provisioning system uses three interconnected state machines:

#### Website Provisioning States
Located in: `app/models/pwb/website.rb`

```
pending -> subdomain_allocated -> configuring -> seeding -> ready -> live
                                                              |
                                                              v
                                                          suspended -> terminated
                                                              ^
                                                              |
         failed <--------------------------------------------+
```

| State | Progress | Description |
|-------|----------|-------------|
| `pending` | 0% | Initial state, waiting to start |
| `subdomain_allocated` | 20% | Subdomain has been reserved/assigned |
| `configuring` | 40% | Website settings being configured |
| `seeding` | 70% | Sample content being added |
| `ready` | 95% | Provisioning complete, ready for review |
| `live` | 100% | Website is publicly accessible |
| `failed` | - | Provisioning failed (can retry) |
| `suspended` | - | Website temporarily disabled |
| `terminated` | - | Website permanently removed |

#### User Onboarding States
Located in: `app/models/pwb/user.rb`

```
lead -> registered -> email_verified -> onboarding -> active
  |                                                      ^
  |                        |                             |
  +------------------------+-----------------------------+
                           |
                           v
                        churned -> (can reactivate to lead)
```

| State | Step | Description |
|-------|------|-------------|
| `lead` | 0 | Email captured, no password yet |
| `registered` | 1 | Password set, account created |
| `email_verified` | 2 | Email address confirmed |
| `onboarding` | 1-3 | Going through setup wizard |
| `active` | 4 | Fully onboarded user |
| `churned` | - | User abandoned signup |

#### Subdomain Pool States
Located in: `app/models/pwb/subdomain.rb`

```
available -> reserved -> allocated -> released -> available
                 |            |
                 +-> released-+
```

| State | Description |
|-------|-------------|
| `available` | In the pool, ready to be assigned |
| `reserved` | Temporarily held for a user (10 min default) |
| `allocated` | Permanently assigned to a website |
| `released` | Released from a website, pending cleanup |

### 2. Key Services

#### ProvisioningService
Location: `app/services/pwb/provisioning_service.rb`

Orchestrates the complete provisioning workflow:

```ruby
service = Pwb::ProvisioningService.new

# Step 1: Start signup (capture email, reserve subdomain)
result = service.start_signup(email: "user@example.com")

# Step 2: Configure site (choose subdomain, site type)
result = service.configure_site(
  user: user,
  subdomain_name: "my-agency",
  site_type: "residential"
)

# Step 3: Provision website (seed content, go live)
result = service.provision_website(website: website)
```

#### SubdomainGenerator
Location: `app/services/pwb/subdomain_generator.rb`

Generates Heroku-style subdomain names (adjective-noun-number):

```ruby
SubdomainGenerator.generate           # => "sunny-meadow-42"
SubdomainGenerator.generate_batch(10) # => ["bright-valley-18", ...]
SubdomainGenerator.populate_pool(count: 100)
SubdomainGenerator.validate_custom_name("my-agency")
```

### 3. Database Schema

#### pwb_subdomains table
```ruby
create_table :pwb_subdomains do |t|
  t.string :name, null: false           # The subdomain name
  t.string :aasm_state, null: false     # Current state
  t.references :website                  # Associated website (when allocated)
  t.datetime :reserved_at               # When reservation started
  t.datetime :reserved_until            # Reservation expiry
  t.string :reserved_by_email           # Email that reserved it
  t.timestamps
end
```

#### Website additions
```ruby
add_column :pwb_websites, :provisioning_state, :string
add_column :pwb_websites, :site_type, :string
add_column :pwb_websites, :seed_pack_name, :string
add_column :pwb_websites, :provisioning_started_at, :datetime
add_column :pwb_websites, :provisioning_completed_at, :datetime
add_column :pwb_websites, :provisioning_error, :text
```

#### User additions
```ruby
add_column :pwb_users, :onboarding_state, :string
add_column :pwb_users, :onboarding_step, :integer
add_column :pwb_users, :onboarding_started_at, :datetime
add_column :pwb_users, :onboarding_completed_at, :datetime
```

## Signup Flow

### Step 1: Email Capture
1. User enters email on signup page
2. System creates a "lead" user (no password yet)
3. System reserves a subdomain from the pool
4. User is redirected to configuration page

### Step 2: Site Configuration
1. User can accept reserved subdomain or choose custom name
2. User selects site type (residential, commercial, vacation_rental)
3. Website record created with chosen settings
4. User set as owner via UserMembership

### Step 3: Provisioning
1. Website transitions through provisioning states
2. Seed pack applied based on site type
3. Sample properties and content added
4. Website goes live
5. User marked as active

## Rake Tasks

```bash
# Populate the subdomain pool
rake provisioning:populate_subdomains

# View provisioning statistics
rake provisioning:stats

# Run a simulated signup flow
rake provisioning:simulate

# Clean up expired reservations
rake provisioning:cleanup_expired
```

## Configuration

### Site Types
Defined in `Website::SITE_TYPES`:
- `residential` - Standard real estate agency
- `commercial` - Commercial property focus
- `vacation_rental` - Holiday rentals and vacation homes

### Subdomain Rules
- Minimum 5 characters, maximum 40
- Lowercase letters, numbers, and hyphens only
- Cannot start or end with hyphen
- Reserved names blocked (admin, www, api, etc.)

## Testing

Specs are located in:
- `spec/models/pwb/subdomain_spec.rb`
- `spec/models/pwb/website_provisioning_spec.rb`
- `spec/models/pwb/user_onboarding_spec.rb`
- `spec/services/pwb/subdomain_generator_spec.rb`
- `spec/services/pwb/provisioning_service_spec.rb`

Run all provisioning specs:
```bash
bundle exec rspec spec/models/pwb/subdomain_spec.rb \
  spec/models/pwb/website_provisioning_spec.rb \
  spec/models/pwb/user_onboarding_spec.rb \
  spec/services/pwb/subdomain_generator_spec.rb \
  spec/services/pwb/provisioning_service_spec.rb
```

## Future Considerations

1. **Payment Integration**: Add payment gate between configuration and provisioning
2. **Email Verification**: Implement proper email verification flow
3. **Background Jobs**: Move provisioning to background job for better UX
4. **Domain Customization**: Allow custom domain setup during onboarding
5. **Plan Selection**: Add subscription tier selection to configuration
