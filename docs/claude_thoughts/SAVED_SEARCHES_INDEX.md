# Saved Searches & Email Alerts - Documentation Index

## Overview

This is the planning documentation for implementing **Saved Searches and Email Alerts** for external property listings in PropertyWebBuilder.

**Status:** Ready for implementation (all patterns and supporting infrastructure identified)

---

## Documentation Files

### 1. Quick Reference (START HERE)
**File:** `implementation_quick_reference.md`  
**Size:** 554 lines  
**Purpose:** Quick lookup guide for implementation

**Contains:**
- Feature status checklist
- Database models summary (3 models to create)
- Code pattern templates (Mailer, Job, Models)
- Multi-tenancy setup guide
- Search parameter structure
- Controller structure outline
- Migration templates
- Route definitions
- Testing strategy
- Performance tips

**Best for:** Quick reference while coding

---

### 2. Comprehensive Exploration
**File:** `saved_searches_email_alerts_exploration.md`  
**Size:** 1,015 lines  
**Purpose:** Deep dive analysis of codebase and architecture

**Contains (in order):**

1. **Executive Summary**
   - Feature status overview
   - What patterns already exist

2. **Saved Search Functionality (Current State)**
   - External listings controller deep dive
   - External feed service architecture
   - Search result structures
   - Property data structures

3. **User Authentication & Accounts**
   - User model with Devise
   - Multi-website support
   - User memberships and roles

4. **Email Notification System**
   - ApplicationMailer base class
   - EnquiryMailer example
   - Email sending pattern
   - Custom Liquid templates

5. **Background Job System**
   - Solid Queue configuration (NOT Sidekiq)
   - ApplicationJob with retries
   - TenantAwareJob concern
   - Example: NtfyNotificationJob
   - Usage patterns

6. **Multi-Tenancy Architecture**
   - Pwb:: vs PwbTenant:: models
   - ActsAsTenant scoping
   - Job tenant handling

7. **Ntfy Notification System**
   - Admin push notifications
   - Configuration in Website model
   - Listing notification concern

8. **Data Models - Message & Contact Flow**
   - Message model for inquiries
   - Contact model for profiles
   - Database schema

9. **Favorite/Bookmark Functionality**
   - Current state: doesn't exist
   - Optional feature to build

10. **Database Architecture**
    - Key tables relevant to feature
    - Existing columns and indexes

11. **Recommended Database Models**
    - ExternalSearch model specification
    - SearchAlert model specification
    - SavedProperty model specification (optional)
    - Detailed column definitions

12. **Email Alert Sending Pattern**
    - New SearchAlertMailer template
    - New SearchAlertJob template
    - Scheduling approach

13. **Implementation Roadmap**
    - 6 phases of development
    - Estimated timeline

14. **Key Architecture Decisions**
    - 5 major decisions with rationale

15. **Patterns to Follow from Codebase**
    - 4 key patterns with examples

16. **Considerations & Gotchas**
    - 6 important considerations

17. **References in Codebase**
    - Key files to reference
    - Key gems used

**Best for:** Understanding the architecture and making design decisions

---

## Quick Navigation

### By Task

**I want to...**

1. **Understand what needs to be built**
   → See: Quick Reference, "Database Models to Create"

2. **Understand existing patterns**
   → See: Exploration, sections 2-7

3. **Understand multi-tenancy**
   → See: Exploration, section 6 + Quick Reference, "Multi-Tenancy Setup"

4. **Understand email pattern**
   → See: Quick Reference, "Email Patterns" + Exploration, section 3

5. **Understand background jobs**
   → See: Quick Reference, "Background Job Patterns" + Exploration, section 4

6. **See code templates**
   → See: Quick Reference, sections 2-8

7. **Create database migrations**
   → See: Quick Reference, "Migration Template"

8. **Create models**
   → See: Exploration, section 11

9. **Create mailer**
   → See: Quick Reference, "Email Patterns"

10. **Create background job**
    → See: Quick Reference, "Background Job Patterns"

11. **Set up routes**
    → See: Quick Reference, "Routes"

12. **Write tests**
    → See: Quick Reference, "Testing Strategy"

13. **Optimize performance**
    → See: Quick Reference, "Performance Considerations"

14. **Plan the full implementation**
    → See: Exploration, section 13 "Implementation Roadmap"

---

### By Audience

**If you are...**

- **Product Manager**: Read Quick Reference sections 1-3
- **Backend Engineer**: Read both documents cover to cover
- **Frontend Engineer**: Read Quick Reference, focus on UI sections
- **DevOps/Infra**: Read Quick Reference "Performance" and background job sections
- **QA/Tester**: Read Quick Reference "Testing Strategy"
- **Technical Architect**: Read Exploration section 13-16 (decisions and patterns)

---

## Key Findings

### Status Summary

| Item | Status | Notes |
|------|--------|-------|
| Saved Searches | ❌ Doesn't exist | Need to create |
| Email Alerts | ❌ Doesn't exist | Need to create |
| Favorite Properties | ❌ Doesn't exist | Optional feature |
| External Feed | ✅ Exists | Ready to use |
| Email System | ✅ Exists | Pattern established |
| Background Jobs | ✅ Exists | Solid Queue v1.0 |
| Multi-Tenancy | ✅ Exists | Well documented |
| User Auth | ✅ Exists | Devise + multi-website |

### Models to Create

1. **Pwb::ExternalSearch** (+ PwbTenant::ExternalSearch)
   - Stores saved search criteria as JSON
   - User + Website links
   - Alert frequency configuration
   - Tracking fields

2. **Pwb::SearchAlert** (+ PwbTenant::SearchAlert)
   - Tracks individual search runs
   - Stores new/changed properties
   - Email delivery tracking

3. **Pwb::SavedProperty** (optional)
   - Allows bookmarking properties
   - Quick display without re-fetching
   - Optional price change alerts

### Patterns to Follow

1. **Mailer Pattern**: Follow `Pwb::EnquiryMailer`
   - Use after_deliver callbacks
   - rescue_from for error handling
   - deliver_later for async

2. **Job Pattern**: Follow `Pwb::NtfyNotificationJob`
   - Include TenantAwareJob
   - Use with_tenant(website_id) { }
   - Automatic retries via ApplicationJob

3. **Model Pattern**: Follow Contact/Message pattern
   - Create Pwb:: (non-tenant) version
   - Create PwbTenant:: (tenant) version
   - Include RequiresTenant in tenant version
   - Use acts_as_tenant

4. **JSON Storage**: Follow existing pattern
   - Store flexible data as JSON
   - No migrations needed for changes
   - Query with JSON operators

---

## Files Referenced in Analysis

### Models
- `/app/models/pwb/user.rb` - User authentication
- `/app/models/pwb/contact.rb` - Contact scoping pattern
- `/app/models/pwb/message.rb` - Message model
- `/app/models/pwb/website.rb` - Website/tenant model

### Services
- `/app/services/pwb/external_feed/base_provider.rb` - Search interface
- `/app/services/pwb/external_feed/manager.rb` - Provider manager
- `/app/services/pwb/external_feed/normalized_search_result.rb` - Result structure
- `/app/services/pwb/external_feed/normalized_property.rb` - Property structure

### Controllers
- `/app/controllers/site/external_listings_controller.rb` - Search params
- `/app/controllers/pwb/props_controller.rb` - Email usage example

### Jobs
- `/app/jobs/application_job.rb` - Base job class
- `/app/jobs/concerns/tenant_aware_job.rb` - Tenant pattern
- `/app/jobs/ntfy_notification_job.rb` - Example job

### Mailers
- `/app/mailers/pwb/application_mailer.rb` - Base mailer
- `/app/mailers/pwb/enquiry_mailer.rb` - Email pattern

### Concerns
- `/app/models/concerns/ntfy_listing_notifications.rb` - Notification pattern

---

## Implementation Timeline

### Recommended Phases

**Phase 1: Models** (1-2 days)
- Create migrations
- Create models with associations
- Add validations
- Write model tests

**Phase 2: Background Job** (1-2 days)
- Implement SearchAlertJob
- Search execution logic
- Change detection logic
- Job tests

**Phase 3: Mailer** (1 day)
- Create SearchAlertMailer
- Email templates (ERB + Liquid)
- Mailer tests

**Phase 4: Controllers & Routes** (2-3 days)
- Create ExternalSearchesController
- Create views (save, edit, list, results)
- Add routes
- Controller tests

**Phase 5: UI & Frontend** (2-3 days)
- Add "Save Search" button to search results
- Create saved search dashboard
- Add search editing interface
- Add frequency configuration UI
- Integration tests

**Phase 6: Deployment** (1 day)
- Setup cron for scheduled searches
- Monitor email delivery
- Handle edge cases
- Performance tuning

**Total Estimated Time:** 8-14 days for full implementation

---

## Next Steps

1. **Review** both documents to understand architecture
2. **Decide** which optional features to include (e.g., SavedProperty)
3. **Plan** implementation phases and timeline
4. **Create** database migrations
5. **Build** models with tests
6. **Build** background jobs with tests
7. **Build** mailer with tests
8. **Build** controllers and UI
9. **Test** end-to-end flow
10. **Deploy** and monitor

---

## Questions?

Refer to specific sections in the documentation:

- **Architecture questions**: See Exploration, sections 13-16
- **Code pattern questions**: See Quick Reference, code templates
- **Database schema questions**: See Exploration, section 11
- **Implementation questions**: See Exploration, section 13
- **How-to questions**: See Quick Reference, "By Task" section above

---

## Document Metadata

**Created:** January 1, 2026  
**Last Updated:** January 1, 2026  
**Status:** Complete and ready for implementation  
**Codebase Explored:** PropertyWebBuilder (develop branch)  
**Explorer:** Claude Code

**Files in this exploration:**
1. `saved_searches_email_alerts_exploration.md` - Comprehensive analysis (1,015 lines)
2. `implementation_quick_reference.md` - Quick guide (554 lines)
3. `SAVED_SEARCHES_INDEX.md` - This file

**Total Documentation:** ~1,600 lines of analysis and templates
