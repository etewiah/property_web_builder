# Duplicate Settings - Quick Reference

## Company Display Name

### Storage
- **Pwb::Website.company_display_name** - Primary storage
- **Pwb::Agency.display_name** - Secondary/fallback
- **Pwb::Agency.company_name** - Legal name (also used as fallback)

### Admin Forms
| Location | Field | Model | Affects |
|----------|-------|-------|---------|
| `/site_admin/website/settings?tab=general` | company_display_name | Website | Primary |
| `/site_admin/agency` | display_name | Agency | Fallback only |
| `/site_admin/agency` | company_name | Agency | Fallback only |

### Precedence (on public site)
```
website.company_display_name.presence
  || agency.display_name  (or agency.company_name in some themes)
  || "Property" / "Real Estate" (hardcoded fallback)
```

### Impact
- **Set website value?** Uses that immediately
- **Set agency value?** Only displays if website value is empty
- **Change one?** May not see changes if the other is already set

**Files affected:** 24 ERB files (headers, footers, contact info blocks across all themes)

---

## Logo URL

### Storage
- ~~**Pwb::Website.main_logo_url** - UNUSED (column exists but never set/used)~~
- **Pwb::Website.logo_url** (method) - Returns logo from content/page_parts
  - Looks for "logo" content block
  - Returns first photo from that content block
  - **File:** `/app/models/concerns/pwb/website_styleable.rb:110`

### Admin Forms
| Location | Field | Type |
|----------|-------|------|
| Content Management | "logo" content block | Content with photos |
| No dedicated logo form | - | - |

### Precedence
```
website.logo_url (from content photos)
  || (text fallback: company display name or hardcoded text)
```

### Impact
- Logo is managed through content/page system, NOT a simple URL field
- `main_logo_url` column is dead code

**Files affected:** Barcelona, Brisbane, Default themes (header/footer)

---

## Email Addresses

### Storage
**Pwb::Website** (UNUSED):
- email_for_general_contact_form
- email_for_property_contact_form
- owner_email

**Pwb::Agency** (ACTIVELY USED):
- email_primary
- email_for_general_contact_form
- email_for_property_contact_form

### Admin Forms
| Location | Fields | Model |
|----------|--------|-------|
| `/site_admin/agency` | All three | Agency ✓ |
| Website settings | Listed in schema but NOT in UI | Website ✗ |

### Precedence
```
agency.email_for_*
  (website fields are ignored)
```

### Impact
- Website email fields are completely unused
- All contact forms and email delivery use Agency emails
- Editing website email fields has no effect

**Files affected:** Email templates, contact form handlers, theme contact blocks

---

## Phone Numbers

### Storage
- **Pwb::Website** - No phone field
- **Pwb::Agency** - phone_number_primary, phone_number_mobile, phone_number_other

### Admin Forms
| Location | Model |
|----------|-------|
| `/site_admin/agency` | Agency ✓ |
| Website settings | - |

### Usage
Always from agency only.

---

## Contact Information

### Summary
| Data | Website | Agency | Used Where |
|------|---------|--------|-----------|
| Company name | ✓ company_display_name | ✓ display_name + company_name | Display + emails |
| Logo | ✓ (from content) | ✗ | Display |
| Email (general) | ✓ (unused) | ✓ (used) | Emails + forms |
| Email (property) | ✓ (unused) | ✓ (used) | Emails + forms |
| Phone | ✗ | ✓ | Display |
| URL | ✗ | ✓ | Links |

---

## Why This Happened

1. **Website model** - Site-wide configuration, originally held everything
2. **Agency model** - Added later to separate agency-specific contact info
3. **Lazy migration** - Old website fields left in place for backwards compatibility
4. **Incomplete refactoring** - Logo and email logic split across multiple locations

---

## Action Items

### High Priority
- [ ] Document in project that **Agency** is the source of truth for contact info
- [ ] Add UI notices showing which fields are actually used
- [ ] Decide: consolidate settings or clearly mark unused fields

### Medium Priority
- [ ] Remove `main_logo_url` column (dead code)
- [ ] Remove unused website email fields from database
- [ ] Add integration tests checking precedence logic

### Low Priority
- [ ] Standardize precedence logic across all themes
- [ ] Create admin UI section combining website + agency settings
- [ ] Extract precedence logic into model methods

---

## Key Files to Review

### Models
- `/app/models/pwb/website.rb` - Main website config
- `/app/models/pwb/agency.rb` - Agency/contact info
- `/app/models/concerns/pwb/website_styleable.rb` - Logo logic

### Admin Forms
- `/app/views/site_admin/website/settings/_general_tab.html.erb`
- `/app/views/site_admin/agency/edit.html.erb`

### Controllers
- `/app/controllers/site_admin/website/settings_controller.rb`
- `/app/controllers/site_admin/agency_controller.rb`

### Theme Views (sample)
- `/app/themes/default/views/pwb/_footer.html.erb`
- `/app/themes/barcelona/views/pwb/_header.html.erb`
- `/app/themes/brisbane/views/pwb/_header.html.erb`
