# Claude's Research & Analysis Notes

This folder contains exploratory research, analysis, and debugging notes created by Claude during development sessions. These documents capture deep-dives into system architecture and troubleshooting investigations.

## Website Seeding Analysis

Comprehensive analysis of how PropertyWebBuilder seeds new websites with navigation items and content.

### Documents

### 1. **[website_seeding_analysis.md](website_seeding_analysis.md)** - Complete Technical Reference
   - **Length**: ~700 lines
   - **Best for**: Understanding the complete system
   - **Contents**:
     - Architecture overview
     - State machine details
     - ProvisioningService workflow
     - Seed pack system
     - How navigation links are created (2 paths)
     - How contents are seeded
     - Multi-tenancy impact
     - Available seed packs
     - Debugging commands
     - Complete flow diagram

   **Start here if**: You're implementing new features or fixing seeding bugs

### 2. **[seeding_issues_summary.md](seeding_issues_summary.md)** - Quick Reference Guide
   - **Length**: ~400 lines
   - **Best for**: Finding answers quickly
   - **Format**: Q&A with code examples
   - **Contents**:
     - Q1: Where are navigation links created?
     - Q2: Why would navigation links be missing?
     - Q3: Where are "contents" seeded?
     - Q4: Why would content be missing?
     - Q5: What's the correct provisioning flow?
     - Q6: How can I reseed navigation links?
     - Q7: What data is scoped per website?
     - Q8: How do I verify everything was seeded?
     - Q9: What's in each seed pack?
     - Q10: How do I create a custom seed pack?
     - Common fixes
     - Testing examples

   **Start here if**: You just want answers to specific questions

### 3. **[seeding_architecture_diagram.md](seeding_architecture_diagram.md)** - Visual Reference
   - **Length**: ~300 lines
   - **Best for**: Understanding flow visually
   - **Format**: ASCII diagrams and flowcharts
   - **Contents**:
     - High-level user signup workflow
     - Detailed provisioning workflow
     - Navigation links seeding flow (both paths)
     - Content seeding flow
     - Multi-tenancy scoping diagram
     - State machine transitions with guards
     - File map
     - Debugging workflow

   **Start here if**: You're visual learner or need to debug a specific flow

---

## Quick Navigation

### Finding Information by Topic

#### **Navigation Links (Menus)**
- File: `seeding_issues_summary.md` - Q1, Q2, Q6
- File: `website_seeding_analysis.md` - Section 4, 6
- File: `seeding_architecture_diagram.md` - "Navigation Links Seeding"

#### **Content Seeding**
- File: `seeding_issues_summary.md` - Q3, Q4
- File: `website_seeding_analysis.md` - Section 5
- File: `seeding_architecture_diagram.md` - "Content Seeding"

#### **Seed Packs**
- File: `seeding_issues_summary.md` - Q9, Q10
- File: `website_seeding_analysis.md` - Section 3, 8
- Directory: `db/seeds/packs/` (actual packs)

#### **Provisioning Workflow**
- File: `seeding_issues_summary.md` - Q5
- File: `website_seeding_analysis.md` - Section 1, 2
- File: `seeding_architecture_diagram.md` - "High-Level Flow"

#### **Multi-Tenancy**
- File: `website_seeding_analysis.md` - Section 7
- File: `seeding_architecture_diagram.md` - "Multi-Tenancy Scoping"

#### **Debugging**
- File: `website_seeding_analysis.md` - Section 10
- File: `seeding_architecture_diagram.md` - "Debugging Workflow"

---

## Key Code Files Referenced

### Services
- `app/services/pwb/provisioning_service.rb` (525 lines)
  - Main orchestrator
  - Steps 1-7 of provisioning
  - Link/content seeding logic

### Models  
- `app/models/pwb/website.rb` (855 lines)
  - AASM state machine
  - Provisioning guards
  - Status checking methods

- `app/models/pwb/link.rb` (53 lines)
  - Link model with Mobility translations
  - Scopes for navigation placement

- `app/models/pwb/content.rb` (93 lines)
  - Content model with Mobility translations
  - Multi-language support

### Libraries
- `lib/pwb/seed_pack.rb` (790 lines)
  - Main seeding system
  - Reusable data bundles
  - All seed_* methods

- `lib/pwb/pages_seeder.rb` (114 lines)
  - Creates pages and page parts
  - Used as fallback in provisioning

- `lib/pwb/contents_seeder.rb` (98 lines)
  - Legacy content seeding
  - Global seed files

### Seed Data
- `db/seeds/packs/base/` - Default pack
  - `links.yml` - 11 navigation items
  - `field_keys.yml` - 35+ property fields
  - NO content, pages, or properties

- `db/seeds/packs/spain_luxury/` - Example pack
  - Inherits from base
  - Adds content and properties

- `db/seeds/packs/netherlands_urban/` - Example pack
  - Inherits from base
  - Adds content

### Tests
- `spec/services/pwb/provisioning_seeding_spec.rb` (297 lines)
  - Full integration tests
  - Individual step tests
  - Error handling tests
  - Idempotency tests

---

## Common Problems & Solutions

| Problem | Question | Answer |
|---------|----------|--------|
| No navigation links after provisioning | Q2 | Check seed pack exists and seed_pack_name is set |
| Links appear without titles | Q2 | Fallback links missing link_title attribute |
| Content not seeded | Q4 | ProvisioningService doesn't call content seeding |
| Can't reseed links | Q6 | Early return check prevents re-seeding if count >= 3 |
| Cross-tenant data leakage | Q7 | Must use website.links, not Pwb::Link |
| Need custom packs | Q10 | Create directory in db/seeds/packs/ with pack.yml |

---

## Implementation Checklist

### When Creating New Website
- [ ] Understand the 3-step signup flow (start → configure → provision)
- [ ] Know that seed_pack_name must be set during configure_site
- [ ] Verify 'base' pack exists and is valid
- [ ] Remember that content seeding is NOT automatic
- [ ] Check provisioning_state transitions pass guard checks

### When Debugging Missing Data
- [ ] Check website.provisioning_state (should be 'live' or 'ready')
- [ ] Verify website.seed_pack_name is set correctly
- [ ] Count existing resources: links.count, field_keys.count, etc.
- [ ] Check if early-return prevented seeding
- [ ] Manually reseed with pack.seed_links! / pack.seed_content!

### When Creating Custom Packs
- [ ] Create `db/seeds/packs/my_pack/` directory
- [ ] Create `pack.yml` with metadata
- [ ] Add `links.yml` for navigation (11 items recommended)
- [ ] Add `field_keys.yml` for property fields (35+ recommended)
- [ ] Optionally add content/, properties/, pages/, images/
- [ ] Test with `Pwb::SeedPack.find('my_pack').preview`
- [ ] Run full provisioning workflow to test

### When Extending Seeding
- [ ] Understand ProvisioningService handles orchestration
- [ ] Use SeedPack for reusable data bundles
- [ ] Always scope resources to website (use website.links, not Pwb::Link)
- [ ] Add guard checks to Website model state machine
- [ ] Write tests for each seeding step
- [ ] Handle fallbacks when pack unavailable

---

## Data Flow Summary

```
User Signup (3 steps)
  ↓
1. start_signup
   └─ Create lead user + reserve subdomain
  ↓
2. configure_site  
   └─ Create website + set seed_pack_name: 'base' + create owner
  ↓
3. provision_website
   ├─ Try SeedPack (base) for each step
   ├─ Step 1: Create agency
   ├─ Step 2: Create links (11 items from base pack)
   ├─ Step 3: Create field keys (35+ from base pack)
   ├─ Step 4: Create pages + page parts
   ├─ Step 5: Seed properties (optional)
   ├─ Step 6: Final verification
   ├─ Step 7: Enter locked state + send email
   └─ Return to 'locked_pending_email_verification'
  ↓
4. User verifies email
   └─ State: 'locked_pending_registration'
  ↓
5. User creates account
   └─ State: 'live'

OPTIONAL (not automatic):
  └─ Seed content: pack.seed_content!(website: website)
```

---

## Questions?

### For questions about a specific topic, see:

**"Where are X created?"**
- → `seeding_issues_summary.md` Q1-Q4
- → `website_seeding_analysis.md` Section 4-5
- → `seeding_architecture_diagram.md` Relevant flow diagram

**"Why isn't X being created?"**
- → `seeding_issues_summary.md` "Why would X be missing?" sections
- → `website_seeding_analysis.md` Section 6 "Why X Might Be Missing"
- → `seeding_architecture_diagram.md` "Debugging Workflow"

**"How do I fix/change X?"**
- → `seeding_issues_summary.md` "Common Fixes" section
- → `seeding_issues_summary.md` Q6, Q10 for reseed/custom pack examples

**"What's the complete flow?"**
- → `seeding_issues_summary.md` Q5
- → `seeding_architecture_diagram.md` "High-Level Flow"
- → `website_seeding_analysis.md` Section 2

**"How do I debug X?"**
- → `website_seeding_analysis.md` Section 10 "Debugging Seeding Issues"
- → `seeding_architecture_diagram.md` "Debugging Workflow"
- → `seeding_issues_summary.md` Q8 "How do I verify everything was seeded?"

---

## Other Analysis Documents

### [CODE_LOCATIONS.md](CODE_LOCATIONS.md)
Quick reference for finding key code related to website seeding - file paths, method names, and line numbers.

### [provisioning_investigation.md](provisioning_investigation.md)
Investigation into why properties might be missing during website provisioning. Documents the provisioning workflow architecture and property seeding logic.

---

## Related Documentation

- **Signup Flow**: See `docs/signup/` for complete signup API documentation
- **Architecture**: See `docs/architecture/provisioning_state_machine.md` for state machine details
- **Multi-Tenancy**: See `docs/multi_tenancy/` for broader tenant scoping info
- **Seed Packs**: See `docs/seeding/` for seed pack documentation

---

Generated: 2025-12-15
Updated: 2025-12-16

