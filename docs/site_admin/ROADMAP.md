# Site Admin Product & UX Roadmap

This roadmap translates the admin audit into a prioritized delivery plan, optimized for **impact vs effort** and suitable for sprint planning or GitHub milestones.

---

## Guiding Principles

- Reduce cognitive load before adding features
- Make commercial value visible at the point of friction
- Prefer performance and clarity over surface polish
- Admin UX should *guide*, not merely *report*

---

## Short-Term Roadmap (0-4 weeks)

**High impact, low-to-medium effort**

### 1. Dashboard Restructure

**Goal:** Improve clarity, performance, and conversion.

- Split dashboard into 4 primary widgets:
  - Growth
  - Engagement
  - Readiness
  - Subscription
- Replace passive subscription notice with blocking alert + CTA
- Add filters to Recent Activity
- Cache dashboard aggregates per website

**Acceptance Criteria:**
- Dashboard loads with ≤5 SQL queries
- Subscription CTA visible without scrolling
- Users can filter activity by entity type

---

### 2. Performance & N+1 Elimination

**Goal:** Improve perceived speed across admin.

- Add eager loading for:
  - ListedProperty → sale_listing / rental_listing
- Cache counts (properties, messages, contacts)
- Enforce Bullet warnings in development/CI

**Acceptance Criteria:**
- No Bullet warnings on dashboard
- Admin TTFB reduced by ≥30%

---

### 3. Terminology Normalization

**Goal:** Reduce confusion and learning friction.

- Inbox → Unread Messages
- Messages → Conversations
- Contents → Page Sections
- Setup Wizard → Getting Started (unified)

**Acceptance Criteria:**
- Single canonical name per concept
- Navigation labels updated consistently

---

### 4. Empty States & Inline Guidance

**Goal:** Make the admin self-explanatory for new users.

- Educational empty states for:
  - Properties
  - Messages
  - Contacts
- Inline "Why this matters" copy

**Acceptance Criteria:**
- No blank screens without guidance
- Each empty state includes a primary CTA

---

## Medium-Term Roadmap (1-3 months)

**Structural UX and workflow improvements**

### 5. Properties UX Overhaul

**Goal:** Improve listing quality and publishing confidence.

- Property completeness indicator
- Sale / Rent / Draft badges
- Bulk actions (publish, unpublish, delete)
- Tabbed edit interface
- Sticky save / publish bar

**Acceptance Criteria:**
- Users can see completion status at a glance
- No accidental data loss on navigation

---

### 6. Pages & CMS Improvements

**Goal:** Clarify site structure and SEO responsibility.

- Hierarchical page tree
- "View on site" links
- SEO completeness indicators per page

**Acceptance Criteria:**
- Page hierarchy visible
- SEO gaps highlighted per page

---

### 7. Inbox → Lightweight CRM

**Goal:** Turn messages into actionable leads.

- Contact status (New, Active, Cold, Converted)
- Property context shown inline
- Internal notes per conversation
- Response-time indicators

**Acceptance Criteria:**
- Each conversation shows status + last activity
- Notes are internal-only

---

### 8. Media Library Intelligence

**Goal:** Reduce clutter and improve performance.

- Show usage count per asset
- Flag unused or oversized images
- Bulk delete and tagging

**Acceptance Criteria:**
- Users can identify unused media
- Bulk actions supported

---

## Long-Term Roadmap (3-6+ months)

**Strategic product differentiation**

### 9. Guided Onboarding Mode

**Goal:** Increase activation and site quality.

- Enforced onboarding sequence: Domain → Branding → SEO → First Property
- Progressive unlocking of admin sections
- Per-user onboarding state

**Acceptance Criteria:**
- New users guided end-to-end
- Onboarding completion rate measurable

---

### 10. Plan-Aware Admin UX

**Goal:** Increase upgrades without dark patterns.

- Inline plan limits ("3 of 5 properties used")
- Feature gating with explanatory tooltips
- Contextual upgrade prompts

**Acceptance Criteria:**
- Upgrade prompts appear at point of need
- No surprise paywalls

---

### 11. Analytics That Drive Action

**Goal:** Move from reporting to decision support.

- "Top performing properties"
- Lead source attribution
- Suggested actions based on data

**Acceptance Criteria:**
- Each analytics view answers a user question
- At least one recommended action per report

---

### 12. Admin Power Tools

**Goal:** Support professional and agency-scale users.

- Global search across admin
- Command palette
- Activity log filters and exports
- Role-based permissions

**Acceptance Criteria:**
- Power users can complete tasks faster
- Permissions enforce least-privilege access

---

## Quick Reference

| Phase | Items | Duration | Effort |
|-------|-------|----------|--------|
| Short-term | 1-4 | 0-4 weeks | ~10 days |
| Medium-term | 5-8 | 1-3 months | ~25 days |
| Long-term | 9-12 | 3-6 months | ~45 days |

**Total:** ~80 days of focused development

---

## Related Documents

- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) - Detailed technical implementation
- [../architecture/](../architecture/) - System architecture docs

---

*Prepared as a product-grade planning artifact, suitable for internal delivery and investor discussions.*
