# Provisioning State Machine

This document describes the website provisioning state machine that ensures websites are fully set up before going live.

## Overview

The provisioning state machine uses granular states with validation guards to ensure each step of website setup completes successfully before moving to the next. This prevents websites from reaching "live" status without required data like owner, agency, links, and field keys.

## State Flow

```
pending → owner_assigned → agency_created → links_created →
field_keys_created → properties_seeded → ready → live
```

### States

| State | Description | Progress % |
|-------|-------------|------------|
| `pending` | Initial state, waiting for owner assignment | 0% |
| `owner_assigned` | Owner user membership created | 15% |
| `agency_created` | Agency record exists | 30% |
| `links_created` | Navigation links seeded (min 3) | 45% |
| `field_keys_created` | Field keys seeded (min 5) | 60% |
| `properties_seeded` | Sample properties created (optional) | 80% |
| `ready` | All provisioning complete, awaiting go-live | 95% |
| `live` | Website is publicly accessible | 100% |
| `failed` | Provisioning failed at some step | varies |
| `suspended` | Temporarily disabled | - |
| `terminated` | Permanently disabled | - |

### Guards

Each transition has a guard that verifies the required data exists:

| Event | Guard | Requirement |
|-------|-------|-------------|
| `assign_owner!` | `has_owner?` | At least one active owner membership |
| `complete_agency!` | `has_agency?` | Agency record present |
| `complete_links!` | `has_links?` | At least 3 navigation links |
| `complete_field_keys!` | `has_field_keys?` | At least 5 field keys |
| `mark_ready!` | `provisioning_complete?` | All guards pass |
| `go_live!` | `can_go_live?` | Complete + subdomain present |

## Usage

### Provisioning a Website

```ruby
service = Pwb::ProvisioningService.new
result = service.provision_website(website: website)

if result[:success]
  puts "Website is live: #{website.primary_url}"
else
  puts "Failed: #{result[:errors].join(', ')}"
  puts "Missing: #{website.provisioning_missing_items.join(', ')}"
end
```

### Checking Provisioning Status

```ruby
website.provisioning_state      # => "agency_created"
website.provisioning_progress   # => 30
website.provisioning_status_message # => "Agency information saved"

# Detailed checklist
website.provisioning_checklist
# => {
#   owner: { complete: true, required: true },
#   agency: { complete: true, required: true },
#   links: { complete: false, count: 2, minimum: 3, required: true },
#   field_keys: { complete: false, count: 0, minimum: 5, required: true },
#   properties: { complete: false, count: 0, required: false },
#   subdomain: { complete: true, value: "my-agency", required: true }
# }

# What's missing
website.provisioning_missing_items
# => ["links (have 2, need 3)", "field_keys (have 0, need 5)"]
```

### Skipping Property Seeding

Properties are optional. To provision without sample properties:

```ruby
service.provision_website(website: website, skip_properties: true)
```

### Retrying Failed Provisioning

```ruby
if website.failed?
  result = service.retry_provisioning(website: website)
end
```

## Error Handling

When provisioning fails:

1. The website transitions to `failed` state
2. `provisioning_error` contains the error message
3. `provisioning_failed_at` records when it failed
4. The checklist shows what was completed before failure

```ruby
website.provisioning_state    # => "failed"
website.provisioning_error    # => "Links creation failed - need at least 3, have 2"
website.provisioning_checklist[:links][:count] # => 2
```

## Integration with Seed Packs

The provisioning service attempts to use Seed Packs for each step. If a seed pack doesn't exist or fails, fallback defaults are used:

- **Agency**: Creates minimal agency with subdomain-based name
- **Links**: Creates home, properties, about, contact links
- **Field Keys**: Creates basic property types, states, and features
- **Properties**: Skipped if seed pack unavailable (non-fatal)

## Database Schema

```sql
-- Key columns on pwb_websites
provisioning_state VARCHAR DEFAULT 'pending'
provisioning_started_at TIMESTAMP
provisioning_completed_at TIMESTAMP
provisioning_failed_at TIMESTAMP
provisioning_error TEXT
```

## Related Documentation

- [Signup Flow](../signup/01_flow.md) - How websites are created during signup
- [Seed Packs](../seeding/) - Sample data bundles for provisioning
