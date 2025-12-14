# Signup System Documentation

Documentation for PropertyWebBuilder's self-service signup flow that guides new users from email capture to a fully provisioned website.

## Quick Navigation

| Document | Description | Audience |
|----------|-------------|----------|
| [01_flow.md](01_flow.md) | Complete signup flow with architecture diagrams | Developers, Architects |
| [02_api_reference.md](02_api_reference.md) | API endpoints, request/response formats | Frontend Devs, API consumers |
| [03_extraction_guide.md](03_extraction_guide.md) | Guide for extracting signup as a component | Architects, DevOps |
| [04_quick_start.md](04_quick_start.md) | Quick reference and debugging guide | Everyone |

## The 4-Step Signup Flow

```
Email Capture -> Site Config -> Provisioning -> Complete
    (Step 1)       (Step 2)      (Step 3)       (Step 4)
```

1. **Email Capture** - User provides email, system creates lead user and reserves subdomain
2. **Site Configuration** - User chooses subdomain and site type, system creates website
3. **Website Provisioning** - System seeds sample data and deploys website (~30s)
4. **Completion** - User sees success page with website URL and next steps

## Key Endpoints

```
GET  /signup                  # Email form
POST /signup/start            # Create user + reserve subdomain
GET  /signup/configure        # Config form
POST /signup/configure        # Create website
GET  /signup/provisioning     # Progress page
POST /signup/provision        # Trigger seeding (JSON)
GET  /signup/status           # Poll status (JSON)
GET  /signup/complete         # Success page
GET  /signup/check_subdomain  # Validate subdomain (JSON)
```

## Testing Locally

```bash
# Start server
rails s -b 0.0.0.0 -p 3000

# Visit signup
open http://localhost:3000/signup
```

## Related Documentation

- [Provisioning Quick Start](../PROVISIONING_QUICK_START.md) - Rake tasks for manual provisioning
- [Multi-Tenancy](../multi_tenancy/) - How tenant isolation works
- [Seeding](../seeding/) - Seed packs and sample data
