# Multi-Tenancy Quick Reference Guide

## How Tenancy Works in This App

### 1. Tenant Resolution
When a request comes in:
1. **SubdomainTenant concern** extracts subdomain from URL (e.g., `site1.example.com` → `site1`)
2. Looks up **Pwb::Website** by subdomain
3. Stores in **Pwb::Current.website** (thread-local storage)
4. Available throughout request via `current_website` helper

### 2. Accessing Current Tenant

```ruby
# In controllers
current_website              # Via helper method
Pwb::Current.website        # Direct access
@current_website            # Instance variable

# Check if website exists
return redirect_to root_path unless current_website
```

### 3. Scoping Queries to Current Tenant

**REQUIRED PATTERN** - Do this in ALL queries on tenant-scoped models:

```ruby
# ✅ CORRECT
@messages = Pwb::Message.where(website_id: current_website&.id)
@pages = Pwb::Page.where(website_id: current_website.id)
@content = Pwb::Content.where(website_id: current_website&.id).find(params[:id])

# ❌ WRONG - Will return all data from all tenants!
@messages = Pwb::Message.all
@pages = Pwb::Page.find(params[:id])

# ❌ WRONG - Uses association but may not filter
@properties = Pwb::ListedProperty.find(params[:id])
# ✅ CORRECT
@properties = Pwb::ListedProperty.where(website_id: current_website&.id).find(params[:id])

# ✅ ALSO CORRECT - Via association
@pages = current_website.pages
@messages = current_website.messages
```

### 4. Models That MUST Be Scoped

These models contain tenant data and MUST filter by website_id:

- `Pwb::Page`
- `Pwb::Content`
- `Pwb::Contact`
- `Pwb::Message`
- `Pwb::Prop` (legacy property model)
- `Pwb::ListedProperty` (materialized view)
- `Pwb::RealtyAsset`
- `Pwb::PageContent`
- `Pwb::PagePart`
- `Pwb::Link`
- `Pwb::WebsitePhoto`

### 5. Models That Are Tenants Themselves

These should NOT be filtered by website_id:

- `Pwb::Website` - The tenant root
- `Pwb::User` - Can belong to multiple websites
- `Pwb::Agency` - One per website, use current_website.agency

### 6. GraphQL API Tenancy

Set tenant via header for API requests:

```bash
# Set current website for API request
curl -H "X-Website-Slug: my-site-slug" https://api.example.com/graphql
```

### 7. Admin Features Accessing All Tenants

For TenantAdmin controllers that manage multiple websites:

```ruby
# Explicitly access all websites (use with caution!)
@websites = Pwb::Website.unscoped.order(created_at: :desc)
@content = Pwb::Content.unscoped.includes(:website)

# Always specify website filter when listing
@props_for_site = Pwb::Prop.unscoped.where(website_id: @website.id)
```

**ONLY use .unscoped() in TenantAdmin controllers with proper authorization!**

---

## Common Patterns

### Creating New Records

```ruby
# ✅ CORRECT - Explicitly set website
@page = Pwb::Page.new(page_params)
@page.website = current_website
@page.save

# Or in controller
def create
  @page = current_website.pages.build(page_params)
  @page.save
end
```

### Updating Records

```ruby
# Always verify record belongs to current website
@page = Pwb::Page.where(website_id: current_website.id).find(params[:id])

# Update
@page.update(page_params)

# Do NOT do this:
@page = Pwb::Page.find(params[:id])  # ❌ Could be from wrong website
```

### Searching/Filtering

```ruby
# ✅ Base query scoped to current website
@pages = Pwb::Page.where(website_id: current_website.id)

# Then add filters
@pages = @pages.where(visible: true)
@pages = @pages.order(created_at: :desc)
@pages = @pages.limit(10)

# Or chain from association
@pages = current_website.pages.where(visible: true).order(created_at: :desc)
```

### Associations Through Website

```ruby
# Use the website association as your entry point
current_website.pages
current_website.messages
current_website.listed_properties
current_website.contacts

# These automatically filter by website_id
```

---

## Testing Tenancy

### Verify Tenant Isolation

```ruby
# ✅ Test data doesn't leak between subdomains
it 'does not show messages from other websites' do
  site1_message = create(:message, website: website1)
  site2_message = create(:message, website: website2)
  
  get '/site1/admin/messages', subdomain: 'site1'
  expect(assigns(:messages)).to include(site1_message)
  expect(assigns(:messages)).not_to include(site2_message)
end
```

### Set Tenant in Tests

```ruby
# In your spec:
it 'creates message for current website' do
  Pwb::Current.website = website1
  message = Pwb::Message.create(content: 'test')
  expect(message.website).to eq(website1)
end
```

---

## Red Flags / Anti-Patterns

### ❌ DO NOT DO THESE

```ruby
# Query without website filter
@pages = Pwb::Page.all
@page = Pwb::Page.find(params[:id])

# Finding via wrong model
user.pages  # If User.pages not properly scoped!

# Mass assignment of website_id
page_params = params.require(:page).permit(:title, :website_id)

# Assuming current_website without checking
current_website.pages  # If current_website is nil, will error

# CSV export without scoping (see Content model!)
Pwb::Content.all.each { |c| ... }  # Could export all data

# Using unscoped in non-admin contexts
Pwb::Message.unscoped.where(origin_email: 'user@example.com')
```

### ✅ DO THIS INSTEAD

```ruby
# Always filter
@pages = Pwb::Page.where(website_id: current_website&.id)

# Use associations
@pages = current_website.pages

# Check existence
return unless current_website

# Scope exports
Pwb::Content.where(website_id: website&.id).each { |c| ... }

# Use unscoped only in TenantAdmin with authorization
```

---

## Debugging Tenant Issues

### Check Current Tenant

```ruby
# In console or debugger
Pwb::Current.website
Pwb::Current.website&.subdomain
Pwb::Current.website&.id
```

### Verify Subdomain Resolution

```ruby
# Check if subdomain maps to website
Pwb::Website.find_by_subdomain('site1')

# Check reserved subdomains
Pwb::Website::RESERVED_SUBDOMAINS
```

### Find Data Across Tenants

```ruby
# If you need to find a record's website
page = Pwb::Page.unscoped.find(page_id)
page.website
page.website.subdomain

# Check all websites for a record
Pwb::Page.unscoped.where(id: params[:id]).includes(:website)
```

---

## Key Configuration

### Subdomain Configuration

**File:** `/app/models/pwb/website.rb`

```ruby
# Reserved subdomains (cannot be used)
RESERVED_SUBDOMAINS = %w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test demo].freeze

# Validation
validates :subdomain,
          uniqueness: { case_sensitive: false },
          format: { with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/i }
```

### Current Tenant Storage

**File:** `/app/models/pwb/current.rb`

Thread-local attributes (cleared between requests):
```ruby
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
  end
end
```

---

## When to Use Each Pattern

| Scenario | Pattern | Example |
|----------|---------|---------|
| List current website's records | Via association | `current_website.pages` |
| Find current website's record | Via association + find | `current_website.pages.find(id)` |
| API/GraphQL request | Use X-Website-Slug header | `curl -H "X-Website-Slug: site1"` |
| Admin viewing all websites | Use .unscoped() | `Pwb::Website.unscoped.all` |
| Export data for website | Scope query | `where(website_id: website.id)` |
| Create new record | Build via association | `current_website.pages.build` |

---

## Common Mistakes & Fixes

| Mistake | Why Bad | Fix |
|---------|---------|-----|
| `Pwb::Page.find(id)` | Gets ANY page | `Pwb::Page.where(website_id: current_website.id).find(id)` |
| `Pwb::Message.all` | Leaks all data | `Pwb::Message.where(website_id: current_website.id)` |
| `.unscoped()` in public code | Defeats tenancy | Only use in TenantAdmin with authorization |
| `current_website.name` without nil check | Errors if not set | `current_website&.name` or `return unless current_website` |
| Forgetting website_id on create | Record unowned | Always set `record.website = current_website` |
| Using old Pwb::Prop model | Outdated | Use `Pwb::ListedProperty` (materialized view) |

---

## Performance Considerations

### Use Materialized View for Property Reads
```ruby
# ✅ Fast - optimized denormalized view
properties = Pwb::ListedProperty.where(website_id: website.id).visible.for_sale

# ❌ Slow - requires joins
properties = Pwb::RealtyAsset.joins(:sale_listings).where(website_id: website.id)
```

### Refresh Properties View After Writes
```ruby
# After creating/updating properties
Pwb::ListedProperty.refresh  # Refresh materialized view
```

### Index Lookups by Subdomain
```ruby
# Already indexed for fast lookup
website = Pwb::Website.find_by_subdomain('site1')
```

---

## Acts-as-Tenant Gem Status

**Current State:** Not used (ScopedModel concern exists but not adopted)

**Verdict:** 
- Manual scoping was chosen for explicit control
- Would be complex to retrofit into existing code
- Current pattern works if developers follow conventions
- Consider if adding test automation for tenant isolation

See `MULTI_TENANCY_ANALYSIS.md` for full evaluation.
