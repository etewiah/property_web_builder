# Company Display Name and Duplicate Settings Investigation Report

**Date:** 2025-12-27  
**Investigation Scope:** PropertyWebBuilder codebase - Site admin settings vs. Agency profile settings

## Executive Summary

The PropertyWebBuilder application has **intentional duplicate company name settings** spread across two separate admin areas, which can cause confusion and data inconsistencies. This report identifies:

1. Where "Company Display Name" is defined, set, and used
2. Which models store which fields
3. How values are resolved on the public site
4. The precedence logic between different sources
5. Other duplicate settings that follow a similar problematic pattern

---

## 1. Company Display Name - Complete Analysis

### 1.1 Where It's Stored

#### **Pwb::Website Model**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/website.rb`

- **Field:** `company_display_name` (string column)
- **Line:** 10 (schema comment)
- **Usage:** Directly stored on the website record
- **Default:** nil (empty)
- **Included in JSON:** Yes, line 215 - included in `as_json` output

#### **Pwb::Agency Model**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/agency.rb`

- **Fields:**
  - `display_name` (string) - Line 23
  - `company_name` (string) - Line 18
- **Relationship:** `belongs_to :website` - Line 57
- **Usage:** Agency has separate display and legal company names
- **Default:** nil (empty)
- **Included in JSON:** Yes, line 64 - both fields included in `as_json` output

---

### 1.2 Where It's Set in Admin Forms

#### **Site Admin Settings (General Tab)**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/site_admin/website/settings/_general_tab.html.erb`

- **Lines:** 7-16
- **Field Name:** `company_display_name`
- **Form Model:** `@website` (Pwb::Website)
- **Label:** "Company Display Name"
- **Help Text:** "The name displayed on your website"
- **Form Submission:**
  - Routes to: `site_admin_website_settings_path`
  - HTTP Method: PATCH
  - Parameter namespace: `pwb_website[company_display_name]`

**Controller Handling:**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/website/settings_controller.rb`

- **Method:** `update_general_settings` (Line 83)
- **Permitted Params:** Line 219
- **Update Action:** Direct call to `@website.update(filtered_params)` - Line 90

#### **Site Admin Agency Profile**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/site_admin/agency/edit.html.erb`

- **Lines:** 25-39 (Display Name) and 32-38 (Legal Company Name)
- **Fields:**
  - `display_name` (shown to visitors)
  - `company_name` (legal documents and invoices)
- **Form Model:** `@agency` (Pwb::Agency)
- **Form Submission:**
  - Routes to: `site_admin_agency_path`
  - HTTP Method: PATCH
  - Parameter namespace: `pwb_agency[display_name]` and `pwb_agency[company_name]`

**Controller Handling:**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/controllers/site_admin/agency_controller.rb`

- **Method:** `update` (Line 13)
- **Permitted Params:** Lines 28-39
- **Update Action:** Direct call to `@agency.update(agency_params)` - Line 14

#### **Tenant Admin Website Form**
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/views/tenant_admin/websites/_form.html.erb`

- **Lines:** 23-26
- **Field Name:** `company_display_name`
- **Form Model:** `@website` (Pwb::Website)
- **Usage Context:** Multi-tenant admin form for website creation/editing
- **Form Submission:** `tenant_admin_websites_path` or `tenant_admin_website_path`

---

### 1.3 How Values Are Resolved on the Public Site

#### **Precedence Logic Found in Theme Views**

The public site uses a **fallback pattern** with this precedence:

```
website.company_display_name (if present)
  ↓ (fallback if empty)
agency.display_name
  ↓ (fallback if no agency)
"Real Estate" or "Property" (hardcoded defaults)
```

#### **Examples from Theme Files:**

**Default Theme Footer** - `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/views/pwb/_footer.html.erb`
```erb
<h4 class="footer-company-name">
  <%= @current_website.company_display_name.presence || @current_agency.company_name %>
</h4>
```
(Line 7)

**Brisbane Theme Header** - `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/brisbane/views/pwb/_header.html.erb`
```erb
<span class="font-serif text-2xl md:text-3xl text-luxury-navy tracking-wide">
  <%= @current_website.company_display_name.presence || @current_agency.display_name %>
</span>
```
(Line 44)

**Barcelona Theme Header** - `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/barcelona/views/pwb/_header.html.erb`
```erb
<span class="font-display font-semibold text-xl text-warm-900 hidden sm:block">
  <%= @current_website.company_display_name || "Property" %>
</span>
```
(Line 19)

**Barcelona Theme Footer** - `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/barcelona/views/pwb/_footer.html.erb`
```erb
<%= @current_website.company_display_name || "Real Estate" %>
...
&copy; <%= Time.current.year %> <%= @current_agency&.company_name || @current_website.company_display_name %>.
```
(Lines with varying logic)

**Biarritz Theme Footer** - `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/biarritz/views/pwb/_footer.html.erb`
```erb
<h4 class="text-xl font-bold text-amber-400 mb-4">
  <%= @current_website.company_display_name.presence || @current_agency.company_name %>
</h4>
```

---

### 1.4 Key Issues Identified

#### **Issue #1: Inconsistent Precedence Logic Across Themes**

Different themes use different fallback patterns:

| Theme | Primary | Secondary | Tertiary |
|-------|---------|-----------|----------|
| Default | website.company_display_name | agency.company_name | (none) |
| Brisbane | website.company_display_name | agency.display_name | (none) |
| Barcelona | website.company_display_name | (none) | "Property" or "Real Estate" |
| Biarritz | website.company_display_name | agency.company_name | (none) |
| Bologna | website.company_display_name | (none) | "Real Estate" |

**Problem:** No consistent pattern across themes. Some check `.presence`, others check truthiness.

#### **Issue #2: Two Separate Admin Interfaces**

**Website Settings (Site Admin):**
- Sets: `Pwb::Website.company_display_name`
- **Location:** `/site_admin/website/settings?tab=general`
- **Label:** "Company Display Name"
- **Context:** Displays once for all

**Agency Profile (Site Admin):**
- Sets: `Pwb::Agency.display_name` and `Pwb::Agency.company_name`
- **Location:** `/site_admin/agency`
- **Labels:** "Display Name" and "Legal Company Name"
- **Context:** 2 separate fields with different purposes

**Problem:** Admins may not understand which one takes precedence, leading to confusion about which field to edit.

#### **Issue #3: Website Field Takes Precedence Over Agency**

Since `website.company_display_name.presence` is checked first:
- If website.company_display_name is set, agency fields are completely ignored
- Agency.display_name is only a fallback if website.company_display_name is blank

**Problem:** Agency profile edit form doesn't make it clear that the value may not be used.

---

## 2. Other Duplicate Settings Following Same Pattern

### 2.1 Logo URL Settings

**Duplicate Fields:**

1. **Pwb::Website.main_logo_url** (string column)
   - **Location:** `app/models/pwb/website.rb` schema line 33
   - **Admin Form:** Not found in admin UI
   - **Status:** Column exists but NOT editable in admin

2. **Website.logo_url** (virtual method)
   - **Location:** `/app/models/concerns/pwb/website_styleable.rb` line 110
   - **Implementation:** Returns logo from content photos (logo content block)
   - **Admin Form:** Managed via Page Parts/Content system
   - **Status:** Editable via content management UI

3. **Pwb::Agency** (no logo field)
   - **Status:** Agency has no logo support

**Precedence Logic (from theme views):**
```erb
if @current_website.logo_url.present?
  <img src="<%= @current_website.logo_url %>">
else
  (display text fallback)
end
```

**Files Using:**
- `/app/themes/barcelona/views/pwb/_header.html.erb` line 8-22
- `/app/themes/brisbane/views/pwb/_header.html.erb` line 41-46
- `/app/themes/default/views/pwb/_header.html.erb`
- `/app/themes/brisbane/views/pwb/_footer.html.erb` line 42-43

**Problem:** `main_logo_url` column exists but is never set or used. Logo comes exclusively from content photos via `.logo_url` method.

---

### 2.2 Email Address Settings

**Multiple Separate Email Fields:**

**Pwb::Website:**
- `email_for_general_contact_form` (string) - Where general inquiries go
- `email_for_property_contact_form` (string) - Where property inquiries go
- **Admin Form:** `/site_admin/website/settings?tab=general` (implied but not shown in _general_tab.html.erb)
- **Status:** Fields exist but NOT visible in current admin tabs

**Pwb::Agency:**
- `email_primary` (string) - Primary contact email
- `email_for_general_contact_form` (string) - Where general inquiries go
- `email_for_property_contact_form` (string) - Where property inquiries go
- **Admin Form:** `/site_admin/agency/edit.html.erb` lines 57-76
- **Status:** Fully editable

**Precedence Logic in Views:**

Footer uses agency email:
```erb
<% if @current_agency.email_primary.present? %>
  <a href="mailto:<%= @current_agency.email_primary %>">
```
(Multiple theme files, always uses @current_agency)

Email delivery uses agency emails:
```ruby
delivery_email: @current_agency.email_for_general_contact_form
```
(See `/docs/email/email_file_reference.md`)

**Problem:** Website has email fields but views always use agency emails. Website email fields are unused.

---

### 2.3 Contact Information Settings

**Pwb::Website:**
- `owner_email` (string) - Line 43 of website.rb schema
- **Admin Form:** Not found
- **Status:** Field exists, no admin interface

**Pwb::Agency:**
- `phone_number_primary` (string)
- `phone_number_mobile` (string)
- `phone_number_other` (string)
- **Admin Form:** `/site_admin/agency/edit.html.erb` lines 80-98
- **Status:** Fully editable

**Precedence Logic:**

All views use agency phone:
```erb
<% if @current_agency.phone_number_primary %>
  <%= @current_agency.phone_number_primary %>
<% end %>
```
(Multiple theme files)

**Problem:** Website has `owner_email`, agency has phone numbers. No consistency in which model holds contact info.

---

### 2.4 URL/Website Settings

**Pwb::Agency:**
- `url` (string) - "Website URL" - `/site_admin/agency/edit.html.erb` line 42
- **Admin Form:** `/site_admin/agency/edit.html.erb` lines 42-46
- **Status:** Editable

**Pwb::Website:**
- No dedicated URL field (has custom_domain, subdomain)
- **Status:** Different approach (domain-based)

---

## 3. Test Coverage

### E2E Test
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/tests/e2e/admin/site-settings-integration.spec.js`

- **Lines:** 44-83
- **Test Name:** "Company Display Name Changes"
- **What it tests:** Setting company_display_name in site admin and verifying it appears on public site
- **Test Method:** Looks for value on homepage
- **Note:** Tests website.company_display_name flow, but NOT agency precedence

### Unit Test
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/site_admin/website_settings_spec.rb`

- **Lines:** 26-44
- **Test Name:** "updates supported locales successfully"
- **Includes:** `company_display_name: 'Test Company'` in params
- **Status:** Tests general settings update endpoint

---

## 4. Documentation Findings

### Mentioned in:
- `/docs/provisioning/WEBSITE_PROVISIONING_OVERVIEW.md` - Logo setup
- `/docs/02_Data_Models.md` - Website.logo_url
- `/docs/email/email_*` files - Agency email usage pattern
- `/docs/seo/SEO_IMPLEMENTATION_GUIDE.md` - Logo for schema.org

---

## 5. Recommendations

### Critical Issues

1. **Standardize Company Name Settings**
   - **Option A:** Keep only `Pwb::Website.company_display_name`
     - Remove Agency.display_name
     - Keep Agency.company_name for legal docs
     - Update all views to use website value
   
   - **Option B:** Consolidate all settings in Agency
     - Move company_display_name logic to agency
     - Remove from website
     - Make website a reference to agency
   
   - **Option C:** Create explicit precedence documentation
     - Document in CLAUDE.md which field to use where
     - Add clear UI notes in both forms explaining precedence
     - Update theme views to use consistent logic

2. **Fix Logo Settings**
   - **Action:** Remove unused `main_logo_url` column from website table
   - **Action:** Document that logos come only from content/page_parts
   - **Action:** Consider if UI should surface the "logo" content block more prominently

3. **Consolidate Email Settings**
   - **Action:** Remove unused `email_for_*` fields from Pwb::Website
   - **Action:** Document that all emails are managed in Agency profile
   - **Action:** Remove email form fields from website settings (if visible)

4. **Document Duplicate Patterns**
   - Add to `/docs/ARCHITECTURE.md` or `/docs/admin/ADMIN_PATTERNS.md`:
     - Explanation of Website vs. Agency separation
     - Which model owns which data
     - Precedence rules for all duplicate fields

---

## 6. File Reference Summary

### Files Where company_display_name Is Referenced

| File | Line(s) | Context | Type |
|------|---------|---------|------|
| `/app/models/pwb/website.rb` | 10 | Schema definition | Model |
| `/app/models/pwb/website.rb` | 215 | JSON serialization | Model |
| `/app/models/pwb/agency.rb` | 23, 64 | Schema + JSON | Model |
| `/app/controllers/site_admin/website/settings_controller.rb` | 219 | Permitted params | Controller |
| `/app/views/site_admin/website/settings/_general_tab.html.erb` | 7-16 | Form field | View |
| `/app/views/site_admin/agency/edit.html.erb` | 25-39 | Form field (display_name) | View |
| `/app/views/tenant_admin/websites/_form.html.erb` | 24-26 | Form field | View |
| `/app/views/tenant_admin/websites/show.html.erb` | - | Display value | View |
| `/app/views/tenant_admin/websites/index.html.erb` | - | Display value | View |
| `/app/themes/default/views/pwb/_footer.html.erb` | 7 | Template variable | Theme |
| `/app/themes/brisbane/views/pwb/_header.html.erb` | 44 | Template variable | Theme |
| `/app/themes/brisbane/views/pwb/_footer.html.erb` | Multiple | Template variable | Theme |
| `/app/themes/barcelona/views/pwb/_header.html.erb` | 19 | Template variable | Theme |
| `/app/themes/barcelona/views/pwb/_footer.html.erb` | Multiple | Template variable | Theme |
| `/app/themes/bologna/views/pwb/_footer.html.erb` | Multiple | Template variable | Theme |
| `/app/themes/biarritz/views/pwb/_footer.html.erb` | Multiple | Template variable | Theme |
| `/app/views/pwb/_header.html.erb` | 43 | Template variable | Theme |
| `/app/views/pwb/_footer.html.erb` | 7 | Template variable | Theme |
| `/spec/requests/site_admin/website_settings_spec.rb` | 32, 51 | Test data | Test |
| `/tests/e2e/admin/site-settings-integration.spec.js` | 46, 65 | Test data | Test |

---

## Conclusion

The PropertyWebBuilder application intentionally separates website-level and agency-level configuration, but the **Company Display Name** and other fields like emails and logos have created confusion through:

1. **Redundant storage** in two models without clear ownership
2. **Inconsistent UI patterns** for editing these values
3. **Precedence logic scattered across theme views** rather than centralized
4. **Unused database columns** (main_logo_url, website emails)

A strategic refactoring is recommended to consolidate these duplicate settings patterns and provide clear documentation on the intended data model.
