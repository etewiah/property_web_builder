# Social Media Links Implementation Analysis

## Executive Summary

PropertyWebBuilder has a dual-storage system for social media links:

1. **JSON Column Storage** (`social_media` field on `Pwb::Website` and `Pwb::Agency` tables)
   - Used for SEO/Open Graph metadata and general settings
   - Edited via admin "SEO Settings" tab
   
2. **Links Model Storage** (Pwb::Link records with placement: `social_media`)
   - Used for displaying footer social media icons
   - Accessed via concern methods (e.g., `website.social_media_facebook`)
   - NOT currently editable via admin UI

This creates a **critical gap**: The links used for footer display are hardcoded via concern methods and not easily manageable through the admin interface.

---

## 1. Data Storage

### Schema: `pwb_websites` and `pwb_agencies` Tables

Both tables have a `social_media` JSON column:

```sql
t.json "social_media", default: {}  -- Line 127 in pwb_agencies, Line 851 in pwb_websites
```

**Current JSON Structure** (from SEO tab):
```json
{
  "og_image": "https://example.com/og-image.jpg",
  "twitter_card": "summary_large_image",
  "twitter_handle": "@company",
  "facebook_url": "https://facebook.com/company",
  "instagram_handle": "@company",
  "linkedin_url": "https://linkedin.com/company",
  "google_site_verification": "xxx",
  "bing_site_verification": "xxx"
}
```

### Models

**Pwb::Website** (`/app/models/pwb/website.rb`)
- Includes concern: `Pwb::WebsiteSocialLinkable` (line 94)
- Serializes `social_media` in `as_json` output (line 214)
- Schema field: `social_media` (line 851 in schema.rb)

**Pwb::Agency** (`/app/models/pwb/agency.rb`)
- Has `social_media` JSON field (line 127 in schema.rb)
- No special accessors or concern included

**Pwb::Link** (`/app/models/pwb/link.rb`)
- Enum placement includes `social_media: 2` (line 56)
- Supports link URL storage via `link_url` field
- Multiple scopes exist but NO scope for social_media placement

---

## 2. Admin Edit UI

### Location: Website Settings → SEO Tab

**File**: `/app/views/site_admin/website/settings/_seo_tab.html.erb`

**Editable Fields** (lines 51-102):
- Open Graph Image URL
- Twitter Card Type
- Twitter Handle
- Facebook Page URL
- Instagram Handle
- LinkedIn URL

**Storage Location**: Updates `@website.social_media` JSON field via controller

**Controller Method**: `update_seo_settings` in `/app/controllers/site_admin/website/settings_controller.rb` (line 155)

**Key Code**:
```ruby
def update_seo_settings
  if params[:social_media].present?
    current_social = @website.social_media || {}
    @website.social_media = current_social.merge(params[:social_media].to_unsafe_h)
  end
  
  if @website.update(seo_settings_params)
    redirect_to site_admin_website_settings_tab_path('seo'), notice: 'SEO settings updated successfully'
  end
end
```

### Issue: Social Media Links for Footer

**There is NO admin UI to edit the social media links used in the footer.**

The footer displays social media links via methods defined in concerns:
- `Pwb::WebsiteSocialLinkable` (`/app/models/concerns/pwb/website_social_linkable.rb`)
- `Website::SocialLinkable` (`/app/models/concerns/website/social_linkable.rb`)

These methods look for Link records with specific slugs (NOT editable via UI):
```ruby
def social_media_facebook
  links.find_by(slug: "social_media_facebook")&.link_url
end

def social_media_twitter
  links.find_by(slug: "social_media_twitter")&.link_url
end

def social_media_linkedin
  links.find_by(slug: "social_media_linkedin")&.link_url
end

def social_media_youtube
  links.find_by(slug: "social_media_youtube")&.link_url
end

def social_media_pinterest
  links.find_by(slug: "social_media_pinterest")&.link_url
end
```

---

## 3. Public Site Display

### Platforms Displayed in Footer (by Theme)

#### Default Theme
**File**: `/app/themes/default/views/pwb/_footer.html.erb` (Lines 31-55)

Displays:
- Facebook ✓
- Twitter ✓
- LinkedIn ✓
- YouTube ✓
- Pinterest ✓

Icon Library: FontAwesome (`fa-facebook`, `fa-twitter`, etc.)

#### Bologna Theme
**File**: `/app/themes/bologna/views/pwb/_footer.html.erb` (Lines 40-70)

Displays:
- Facebook ✓
- Twitter (as "X logo") ✓
- LinkedIn ✓
- **Instagram ✓ (NOT in concern methods!)**
- YouTube ✓

Icon Library: Phosphor Icons (`ph-facebook-logo`, `ph-x-logo`, etc.)

#### Brisbane Theme (Luxury)
**File**: `/app/themes/brisbane/views/pwb/_footer.html.erb` (Lines 23-57)

Displays:
- Facebook ✓
- Twitter ✓
- LinkedIn ✓
- **Instagram ✓ (NOT in concern methods!)**
- YouTube ✓

Icon Library: FontAwesome (`fab fa-facebook-f`, `fab fa-x-twitter`, etc.)

### Common Display Pattern

All themes check for the method with `respond_to?` guard:
```erb
<% if @current_website.respond_to?(:social_media_facebook) && @current_website.social_media_facebook.present? %>
  <a href="<%= @current_website.social_media_facebook %>" ...>
```

---

## 4. Supported Platforms (Feature Matrix)

| Platform | JSON Field (SEO) | Link Method | Default Footer | Bologna Footer | Brisbane Footer | Icon Type |
|----------|------------------|-------------|-----------------|----------------|-----------------|-----------|
| Facebook | `facebook_url` | `social_media_facebook` | ✓ | ✓ | ✓ | FA / PH / FA |
| Twitter/X | `twitter_handle` | `social_media_twitter` | ✓ | ✓ | ✓ | FA / PH / FA |
| LinkedIn | `linkedin_url` | `social_media_linkedin` | ✓ | ✓ | ✓ | FA / PH / FA |
| YouTube | - | `social_media_youtube` | ✓ | ✓ | ✓ | FA / PH / FA |
| Pinterest | - | `social_media_pinterest` | ✓ | - | - | FA / - / - |
| Instagram | `instagram_handle` | **MISSING** | - | ✓ | ✓ | PH / FA |

---

## 5. Test Coverage

### Unit Tests for Link Methods
**File**: `/spec/models/concerns/pwb/website/social_linkable_spec.rb`

Tests all 5 platforms:
- `social_media_facebook`
- `social_media_twitter`
- `social_media_linkedin`
- `social_media_youtube`
- `social_media_pinterest`

**Test Strategy**: Creates Link records with hardcoded slugs, verifies accessor methods return correct URLs

### View Tests
**File**: `/spec/views/pwb/bristol_footer_spec.rb`

Tests footer rendering with `social_media` JSON field updates:
```ruby
website.update!(social_media: { "facebook" => "https://facebook.com/test" })
```

**Issue**: Tests update `social_media` JSON field but footer code uses concern methods that look for Link records

---

## 6. Critical Gaps & Issues

### Gap 1: No Admin UI for Footer Social Links
- Admin can edit SEO/Open Graph metadata in "SEO Settings" tab
- But CANNOT edit the actual footer social media links
- Footer links must be created via database seeding or Rails console
- No "Social Media Links" or similar admin section exists

### Gap 2: Concern Methods Don't Cover All Displayed Platforms
**Missing Concern Method**:
- `social_media_instagram` ✗ (NOT defined in concerns)
- BUT displayed in Bologna and Brisbane themes
- Themes call `respond_to?(:social_media_instagram)` which returns FALSE
- Result: Instagram links are never rendered in these themes

**Recommendation**: Add missing method to concerns:
```ruby
def social_media_instagram
  links.find_by(slug: "social_media_instagram")&.link_url
end
```

### Gap 3: Inconsistent Storage Systems
- **SEO metadata** stored in `website.social_media` JSON (editable via UI)
- **Footer links** stored in `Pwb::Link` records (hardcoded via seeding)
- Two separate systems create confusion and maintenance overhead

**Example**: 
- Admin sets "Facebook Page URL" in SEO Settings → Stored in JSON
- But footer displays `website.social_media_facebook` → Looks in Link records
- These are DIFFERENT data sources!

### Gap 4: No Instagram in Link Accessors
- Istanbul & Brisbane themes attempt to render Instagram
- But `social_media_instagram` method NOT defined in `Pwb::WebsiteSocialLinkable`
- Causes silent failures (returns nil, link not rendered)

### Gap 5: Test Data Inconsistency
- Specs test with JSON field updates: `website.update!(social_media: { "facebook" => "..." })`
- But actual code uses Link record accessors
- Tests don't verify actual footer rendering with concern methods
- This masked the Instagram bug

---

## 7. Data Flow Summary

### Current Flow (SEO/Open Graph)
```
Admin UI (SEO Tab)
  ↓
SiteAdmin::Website::SettingsController#update_seo_settings
  ↓
@website.social_media = params[:social_media].merge(...)
  ↓
Pwb::Website (JSON field)
  ↓
Used in templates for og: meta tags or custom handling
```

### Current Flow (Footer Links - BROKEN)
```
Seed YAML (links.yml)
  ↓
Pwb::Seeder#seed_links OR Pwb::SeedPack#seed_links
  ↓
Creates Pwb::Link records with slugs: "social_media_facebook", etc.
  ↓
Pwb::WebsiteSocialLinkable concern methods
  ↓
@current_website.social_media_facebook (etc.)
  ↓
Footer template renders if present
```

**Problem**: No admin UI to manage the Pwb::Link records for social media

---

## 8. Recommendations

### Priority 1: Fix Instagram Support
Add missing method to both concerns:

**File**: `/app/models/concerns/pwb/website_social_linkable.rb`
```ruby
def social_media_instagram
  links.find_by(slug: "social_media_instagram")&.link_url
end
```

**File**: `/app/models/concerns/website/social_linkable.rb`
```ruby
def social_media_instagram
  links.find_by(slug: "social_media_instagram")&.link_url
end
```

### Priority 2: Create Admin UI for Social Links
Add a "Social Links" section in Navigation or SEO settings to allow editing:
- Facebook, Twitter, LinkedIn, YouTube, Pinterest, Instagram
- Store in Pwb::Link records with proper placement
- Or consolidate to JSON field and update concern methods

### Priority 3: Consolidate Storage Strategy
Consider one of:

**Option A**: Use JSON field only
- Store all social links in `website.social_media`
- Update concern methods to read from JSON instead of Link records
- Remove Pwb::Link dependency for social media
- Simplify admin UI

**Option B**: Use Link records only
- Create admin UI to manage social media links like navigation
- Remove custom JSON field approach
- Use Link records for all social media (consistent with nav links)

**Option C**: Clarify separation
- Keep SEO metadata in JSON (`og_image`, `twitter_card`, etc.)
- Use Link records for footer social links
- Create dedicated admin UI for social links
- Document the distinction clearly

### Priority 4: Update Tests
- Test actual footer rendering with Link records
- Verify all platforms display correctly across themes
- Add Instagram tests to spec

---

## 9. Files Involved

### Models & Concerns
- `/app/models/pwb/website.rb` - includes WebsiteSocialLinkable
- `/app/models/pwb/link.rb` - Link model with social_media placement
- `/app/models/concerns/pwb/website_social_linkable.rb` - Accessor methods
- `/app/models/concerns/website/social_linkable.rb` - Duplicate accessors

### Controllers
- `/app/controllers/site_admin/website/settings_controller.rb` - SEO tab updates

### Views
- `/app/views/site_admin/website/settings/_seo_tab.html.erb` - Admin edit UI
- `/app/themes/default/views/pwb/_footer.html.erb` - Default footer display
- `/app/themes/bologna/views/pwb/_footer.html.erb` - Bologna footer display
- `/app/themes/brisbane/views/pwb/_footer.html.erb` - Brisbane footer display

### Seeds
- `/db/seeds/packs/base/links.yml` - Base link definitions
- `/lib/pwb/seeder.rb` - Seeder class
- `/lib/pwb/seed_pack.rb` - SeedPack class

### Tests
- `/spec/models/concerns/pwb/website/social_linkable_spec.rb` - Unit tests
- `/spec/views/pwb/bristol_footer_spec.rb` - View tests

---

## 10. Summary Table

### What Works
- SEO/Open Graph metadata editing (UI → JSON)
- Footer rendering of 5 platforms (Link records → methods → templates)
- Database seeding of links

### What Doesn't Work
- Instagram footer link display (method missing from concerns)
- Admin UI for footer social links (no interface exists)
- Consistency between SEO JSON and Link records

### What's Styled But Non-Functional
- Instagram icon in Bologna & Brisbane themes (method returns nil)
