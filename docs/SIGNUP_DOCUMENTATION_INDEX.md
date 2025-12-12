# Signup Documentation Index

Complete documentation for PropertyWebBuilder's signup system has been created in `/docs/`. This index helps you navigate the comprehensive guides.

---

## Documentation Files

### 1. **signup_quick_start.md** (12 KB) - START HERE
**Target Audience:** Everyone  
**Time to Read:** 5-10 minutes

Quick reference guide with condensed information about the signup system.

**Contains:**
- System architecture diagram
- 4-step overview table
- Key classes and their purposes
- Session data tracking
- Database operations summary
- Critical operations code snippets
- Error handling quick reference
- Routes list
- API response examples
- Common issues & fixes
- Debugging commands

**Best for:** Getting up to speed quickly, finding quick answers

---

### 2. **signup_flow.md** (30 KB) - COMPREHENSIVE GUIDE
**Target Audience:** Developers, Architects  
**Time to Read:** 20-30 minutes

Complete, detailed documentation of the entire signup flow with all implementation details.

**Contains:**
- Architecture diagram with flow visualization
- Step-by-step flow details (4 major sections):
  - Step 1: Email Capture & Lead Creation
  - Step 2: Site Configuration
  - Step 3: Website Provisioning
  - Step 4: Completion
- Database models & state machines
- All API endpoints summary
- Session data passed between steps
- Data flow & persistence details
- Error handling & recovery procedures
- External dependencies (SubdomainGenerator, Seeder, SeedPack, StructuredLogger)
- Security considerations
- Performance considerations
- Testing information
- Extracting as a standalone component
- Monitoring & debugging guide
- Related documentation references
- Future enhancements list

**Best for:** Understanding the complete system, architectural decisions, implementation details

---

### 3. **signup_api_reference.md** (13 KB) - API DOCUMENTATION
**Target Audience:** Frontend Developers, API Consumers  
**Time to Read:** 15-20 minutes

Detailed API endpoint reference with request/response contracts.

**Contains:**
- All 10 signup endpoints documented:
  - Request parameters
  - Response formats
  - Success/error cases
  - HTTP status codes
- Helper endpoints for subdomain validation
- Session management details
- Error codes table
- Rate limiting recommendations
- Example flows (successful signup, failed subdomain check, retry after failure)
- Testing examples (cURL, Ruby)
- Complete API contracts in JSON/Ruby format

**Best for:** Integrating with the signup system, testing endpoints, frontend development

---

### 4. **signup_extraction_guide.md** (18 KB) - EXTRACTION GUIDE
**Target Audience:** Architects, DevOps, Component Extractors  
**Time to Read:** 25-35 minutes

Detailed technical guide for extracting signup into a standalone component or microservice.

**Contains:**
- Component overview and layer architecture
- Complete file manifest with sizes and dependencies
- Dependency analysis (hard and soft)
- Database schema requirements with SQL
- 3 extraction strategies:
  - Rails Engine approach
  - Standalone Microservice approach
  - Modular Classes approach
- Refactoring guide for tight couplings
- Code changes required for extraction
- Testing strategy for extracted component
- Integration points with host application
- Configuration example
- Performance checklist
- Security checklist
- Deployment considerations
- Rollback procedures
- Monitoring queries
- Final considerations for production

**Best for:** Planning component extraction, modularization, containerization

---

## How to Navigate

### I'm a new developer...
1. Start: **signup_quick_start.md**
2. Then: **signup_flow.md** (Sections: "Step 1" through "Step 4")
3. Reference: **signup_api_reference.md** (when building features)

### I'm integrating with signup...
1. Start: **signup_api_reference.md**
2. Reference: **signup_quick_start.md** (for debugging)
3. Deep dive: **signup_flow.md** (if needed for complex integration)

### I'm extracting signup as a component...
1. Start: **signup_extraction_guide.md** (read entirely)
2. Reference: **signup_flow.md** (for architectural details)
3. Reference: **signup_api_reference.md** (for endpoint contracts)

### I need to debug a signup issue...
1. Quick lookup: **signup_quick_start.md** → "Common Issues & Fixes"
2. Debugging: **signup_quick_start.md** → "Debugging Commands"
3. Deep dive: **signup_flow.md** → "Error Handling & Recovery"

### I'm setting up production...
1. Read: **signup_extraction_guide.md** → "Deployment Considerations"
2. Read: **signup_extraction_guide.md** → "Security Checklist"
3. Read: **signup_extraction_guide.md** → "Monitoring Queries"

---

## Key Concepts Quick Reference

### The 4 Steps
1. **Email Capture** - User provides email, system creates lead user and reserves subdomain
2. **Site Configuration** - User chooses subdomain and site type, system creates website
3. **Website Provisioning** - System seeds sample data and deploys website
4. **Completion** - User sees success page and next steps

### Core Models
- **User** - Signup user with onboarding state machine (lead → active)
- **Website** - Tenant website with provisioning state machine (pending → live)
- **Subdomain** - DNS subdomain with reservation/allocation system
- **UserMembership** - Links users to websites with role-based access

### Key Services
- **SignupController** - HTTP request handling, view rendering
- **ProvisioningService** - Business logic orchestration
- **SubdomainGenerator** - Generates and validates subdomain names
- **Seeder** - Seeds sample data for new websites

### Session Variables
```ruby
session[:signup_user_id]      # Set in Step 1
session[:signup_subdomain]    # Set in Step 1
session[:signup_website_id]   # Set in Step 2
# All cleared in Step 4
```

---

## File Locations in Codebase

```
PropertyWebBuilder/
├── app/
│   ├── controllers/pwb/signup_controller.rb
│   ├── views/pwb/signup/
│   │   ├── new.html.erb                    (Step 1)
│   │   ├── configure.html.erb              (Step 2)
│   │   ├── provisioning.html.erb           (Step 3)
│   │   └── complete.html.erb               (Step 4)
│   ├── views/layouts/pwb/signup.html.erb   (Layout)
│   ├── models/pwb/
│   │   ├── user.rb                         (Onboarding state machine)
│   │   ├── website.rb                      (Provisioning state machine)
│   │   ├── subdomain.rb                    (Reservation state machine)
│   │   └── user_membership.rb              (User-website association)
│   └── services/pwb/
│       ├── provisioning_service.rb         (Main orchestrator)
│       └── subdomain_generator.rb          (Name generation & validation)
├── lib/pwb/
│   └── seeder.rb                           (Sample data creation)
├── config/
│   └── routes.rb                           (Signup routes)
├── spec/
│   ├── services/pwb/provisioning_service_spec.rb
│   ├── models/pwb/website_provisioning_spec.rb
│   └── ... (other signup-related tests)
└── docs/
    ├── signup_quick_start.md               (This index)
    ├── signup_flow.md                      (Comprehensive guide)
    ├── signup_api_reference.md             (API docs)
    └── signup_extraction_guide.md          (Extraction guide)
```

---

## Key Files Summary

| File | Lines | Purpose | Complexity |
|------|-------|---------|------------|
| SignupController | 265 | HTTP handling & session mgmt | Low |
| ProvisioningService | 303 | Business logic orchestration | Medium |
| SubdomainGenerator | 167 | Name generation & validation | Medium |
| Seeder | 522 | Sample data creation | Medium-High |
| User model | ~400 | Onboarding state machine | Low |
| Website model | ~600 | Provisioning state machine | Low |
| Subdomain model | ~200 | Reservation state machine | Low |
| Views | 4 files | UI/forms/progress | Low |
| Routes | 10 lines | URL routing | Low |
| **Total** | ~2.5K | **Complete signup system** | |

---

## Performance Characteristics

| Operation | Duration | Bottleneck |
|-----------|----------|------------|
| Email validation | ~50ms | Input validation |
| Subdomain reservation | ~50ms | Database lookup |
| Website creation | ~100ms | Database insert |
| Provisioning | 30-60s | **Seeding & config** |
| Total (start to finish) | ~35s | **Step 3: Provisioning** |

**Note:** Step 3 is currently synchronous. In production, it should be async.

---

## Critical Paths

### Happy Path
```
Email (valid) → Subdomain (available) → Config (valid) → Provision (success) → Complete
```

### Error Paths
```
Email (invalid) → Re-enter email → Retry
Email (in use) → Show error → Restart
Subdomain (taken) → Suggest another → Retry
Provision (failed) → Click Retry → Re-run provision
```

---

## Dependencies

### Hard Dependencies
- Rails 7.0+
- AASM (state machines)
- ActiveRecord (ORM)
- SecureRandom

### Database Requirements
- 6 core tables (users, websites, subdomains, memberships, plus seeded data)
- Indexes on frequently queried columns

### Optional Dependencies
- Devise (authentication)
- I18n (translations)
- ActiveStorage (photos)

---

## Success Criteria

A successful signup:
1. Creates 1 User (onboarding_state: lead → active)
2. Creates 1 Website (provisioning_state: pending → live)
3. Creates 1 Subdomain (aasm_state: available → reserved → allocated)
4. Creates 1 UserMembership (role: owner, active: true)
5. Seeds sample data (agency, properties, links)
6. User receives password reset email
7. Website accessible at subdomain URL
8. User can access admin dashboard

---

## Common Questions

**Q: How long does signup take?**
A: ~35 seconds average (email & config: <1s, provisioning: 30-60s)

**Q: Can users be on multiple websites?**
A: Yes, via UserMembership records. Step 1-2 create primary website.

**Q: What if subdomain reservation expires?**
A: User can choose a different subdomain in Step 2. Reservation lasts 10 minutes.

**Q: Can signup be extracted to a separate service?**
A: Yes, see signup_extraction_guide.md for 3 extraction strategies.

**Q: What happens if provisioning fails?**
A: Website enters 'failed' state. User clicks "Retry" to re-run.

**Q: Are there email verification requirements?**
A: Not during signup. Email verification can be added as feature flag.

---

## Testing

All documents include test information:
- **signup_quick_start.md** → "Testing Signup Locally"
- **signup_flow.md** → "Testing" section
- **signup_api_reference.md** → "Testing Examples"

Run tests:
```bash
bundle exec rspec spec/services/pwb/provisioning_service_spec.rb
bundle exec rspec spec/models/pwb/website_provisioning_spec.rb
```

---

## Support & Debugging

### For Questions About...
- **Overall flow** → signup_flow.md
- **Specific endpoints** → signup_api_reference.md
- **Extracting the component** → signup_extraction_guide.md
- **Quick reference** → signup_quick_start.md

### For Issues...
1. Check "Common Issues & Fixes" in signup_quick_start.md
2. Review "Error Handling & Recovery" in signup_flow.md
3. Use "Debugging Commands" in signup_quick_start.md
4. Examine logs via "Monitoring & Debugging" in signup_flow.md

### For Setup...
1. Read "Deployment Considerations" in signup_extraction_guide.md
2. Review "Security Checklist" in signup_extraction_guide.md
3. Follow "Configuration Example" in signup_extraction_guide.md

---

## Document Metadata

| Document | Size | Last Updated | Version | Audience |
|----------|------|--------------|---------|----------|
| signup_quick_start.md | 12 KB | 2024-12-12 | 1.0 | Everyone |
| signup_flow.md | 30 KB | 2024-12-12 | 1.0 | Developers/Architects |
| signup_api_reference.md | 13 KB | 2024-12-12 | 1.0 | Frontend/API |
| signup_extraction_guide.md | 18 KB | 2024-12-12 | 1.0 | Architects/DevOps |

**Total Documentation:** 73 KB across 4 comprehensive documents

---

## Related Documentation

Check `/docs/` for related topics:
- `docs/architecture/` - System architecture decisions
- `docs/multi_tenancy/` - Multi-tenancy implementation
- `docs/seeding/` - Seed data and seed packs
- `docs/admin/` - Admin interface documentation
- `docs/authentication.md` - Authentication flow

---

## Next Steps

1. **Start Reading:** Begin with signup_quick_start.md (5-10 min read)
2. **Deep Dive:** Read signup_flow.md for complete understanding (20-30 min)
3. **API Integration:** Reference signup_api_reference.md when building (15-20 min)
4. **Planning Extraction:** Study signup_extraction_guide.md if extracting (25-35 min)
5. **Hands-On:** Try signup flow locally or run tests
6. **Debug:** Use debugging guide when issues arise

---

**Questions or Issues?** Refer to the appropriate document above or contact the development team.

