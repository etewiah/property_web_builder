# Fragment Caching Investigation for PropertyWebBuilder

## Executive Summary

PropertyWebBuilder has a mature HTTP caching system but **no fragment caching (Rails view-level caching)** currently implemented except for one search result item partial. Fragment caching needs careful design in edit mode to avoid serving stale content to editors.

The existing "website locking" feature (provisioning state machine) provides a useful model for how to extend locking for website editing permissions.

---

## 1. EDIT MODE DETECTION

### Current Implementation

**Detection Method**: URL parameter `?edit_mode=true`

**Key Files**:
- `/app/controllers/pwb/editor_controller.rb` (lines 13-26)
- `/app/helpers/pwb/component_helper.rb` (line 11)

**How it Works**:
1. Editor controller appends `edit_mode=true` parameter to iframe path:
   ```ruby
   @iframe_path = "#{path}#{separator}edit_mode=true"
   ```

2. In views, check is done via:
   ```ruby
   edit_mode = params[:edit_mode] == 'true'
   ```

3. Example usage in Barcelona theme pages view:
   ```erb
   <%= "data-pwb-page-part=#{page_content.page_part_key}".html_safe if params[:edit_mode] == 'true' %>
   ```

### Limitations of Current Approach

1. **URL-based detection is accessible**: Any user can add `?edit_mode=true` to any URL
2. **No authentication check**: The editor controller has a TODO comment about auth:
   ```ruby
   # TODO: Re-enable authentication before production
   # before_action :authenticate_admin_user!
   ```
3. **Not persistent**: Edit mode exists only for that request, not across page navigation
4. **No session-based state**: No way to know if user is "in edit mode" across multiple requests

### Authentication Status

- **Not currently enforced**: Admin authentication is commented out
- **Needs implementation before production**
- Should use: `current_user && current_user.admin_for?(@current_website)`

---

## 2. CURRENT CACHING ARCHITECTURE

### HTTP Caching (Browser/CDN Level)

**Module**: `HttpCacheable` concern
**Location**: `/app/controllers/concerns/http_cacheable.rb`

**Features**:
- **ETag-based caching** with website ID and locale
- **Cache-Control headers** with configurable max-age and stale-while-revalidate
- **Automatic cache invalidation** via `updated_at` timestamp

**Cache Settings**:
- Pages: 10 minutes cache, 1 hour stale-while-revalidate
- Properties: 10 minutes cache
- Default: 5 minutes cache, 1 hour stale-while-revalidate

**Controllers Using It**:
- `Pwb::PagesController` (lines 39-43)
- `Pwb::PropsController` (lines 20, 52)

### Action/View Caching (Not Used)

**Status**: No action or full-page caching

### Fragment Caching (Minimal Usage)

**Current Implementations**:

1. **Search Result Item** (`/app/views/pwb/search/_search_result_item.html.erb`, lines 1-77):
   ```erb
   <% cache [property_card_cache_key(property, @operation_type), "v2"] do %>
     <!-- Property card HTML -->
   <% end %>
   ```
   - Uses `property_card_cache_key()` helper
   - Includes currency preference
   - Version suffix "v2" allows manual cache busting

2. **Footer Content** (`/app/controllers/pwb/application_controller.rb`, lines 117-123):
   ```ruby
   cache_key = "footer_content/#{current_website&.id}/#{current_website&.updated_at&.to_i}"
   @footer_content = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
     # expensive query
   end
   ```

3. **Navigation Links** (same file, lines 125-138):
   ```ruby
   cache_key = "nav_admin_link/#{current_website&.id}/#{current_website&.updated_at&.to_i}"
   @show_admin_link = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
     # query
   end
   ```

4. **Page Part Templates** (`/app/models/pwb/page_part.rb`, lines 66-71):
   ```ruby
   cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"
   Rails.cache.fetch(cache_key, expires_in: cache_duration) do
     load_template_content
   end
   ```
   - Development: 5 seconds TTL
   - Production: 1 hour TTL

### Cache Store Configuration

**Location**: `/config/initializers/caching.rb`

**Environments**:
- **Production**: Redis cache store with namespace "pwb"
  - Pool size: 5 (configurable via RAILS_MAX_THREADS)
  - Compression: enabled for values > 1KB
  - Reconnect attempts: 3
  - Default expires_in: 1 hour

- **Development**: Memory store (64MB) or Redis if REDIS_URL set
  - Default expires_in: 5 minutes

- **Test**: null_store (no caching)

**Environment Variables**:
- `REDIS_CACHE_URL` (optional, overrides REDIS_URL)
- `REDIS_URL` (defaults to redis://localhost:6379/1)
- `RAILS_MAX_THREADS`

---

## 3. MULTI-TENANCY CACHE KEYS

### Current Pattern

All cache keys follow the format:
```
pwb:w{website_id}:l{locale}:[rest_of_key]
```

**Components**:
1. **Namespace prefix**: "pwb" (set in caching.rb, line 25)
2. **Website ID**: `w{current_website.id}` 
3. **Locale**: `l{I18n.locale}`
4. **Separator**: `:` (slash `/` in Rails cache_key_with_version)

### CacheHelper Implementation

**Location**: `/app/helpers/cache_helper.rb`

**Key Method**: `cache_key_for(*parts)` (lines 20-38)
```ruby
def cache_key_for(*parts)
  website_id = current_website_id
  locale = I18n.locale

  base_parts = ["w#{website_id}", "l#{locale}"]

  expanded_parts = parts.map do |part|
    case part
    when ActiveRecord::Base
      part.cache_key_with_version
    when ActiveRecord::Relation
      part.cache_key_with_version
    else
      part.to_s
    end
  end

  (base_parts + expanded_parts).join("/")
end
```

### Existing Cache Keys

1. **Property Card**: `property_card_cache_key(property, operation_type)`
   - Includes: property ID, updated_at, operation_type, currency
   - Used in: search results

2. **Property Detail Sections**: `property_detail_cache_key(property, section)`
   - Supports sections: "main", "carousel", etc.
   - Includes: photo_updated timestamp for carousel

3. **Page Cache**: `page_cache_key(page)`
   - Includes: page slug, page.updated_at, page_contents.max(updated_at)

4. **Navigation**: `navigation_cache_key()`
   - Includes: website.updated_at, pages.visible.max(updated_at)

5. **Footer**: `footer_cache_key()`
   - Includes: website.updated_at

### current_website_id Lookup Chain

From `CacheHelper#current_website_id` (lines 173-181):
```ruby
def current_website_id
  if defined?(current_website) && current_website
    current_website.id
  elsif defined?(Pwb::Current) && Pwb::Current.website
    Pwb::Current.website.id
  else
    "global"
  end
end
```

**Fallback Priority**:
1. `@current_website` instance variable (set in ApplicationController#current_agency_and_website)
2. `Pwb::Current.website` (ActiveSupport::CurrentAttributes)
3. "global" (fallback)

---

## 4. PAGE RENDERING FLOW

### Data Flow for Pages

**Controller**: `Pwb::PagesController#show_page`
**Location**: `/app/controllers/pwb/pages_controller.rb` (lines 11-47)

**Process**:
1. Find page by slug (default: "home")
2. Extract visible page_contents in order
3. Separate into two arrays:
   - `@content_to_show`: rendered HTML content strings
   - `@page_contents_for_edit`: full PageContent objects (for edit mode)
4. Set HTTP cache headers (10 minutes)
5. Render view

**Key Query**: 
```ruby
@page.ordered_visible_page_contents.each do |page_content|
  if page_content.is_rails_part
    # Rails parts rendered as partials, not cached
    @content_to_show.push nil
  else
    # Liquid content
    @content_to_show.push page_content.content&.raw
  end
  @page_contents_for_edit.push page_content
end
```

### View Rendering

**Theme View**: `/app/themes/barcelona/views/pwb/pages/show.html.erb`

**Structure**:
```erb
<% @page_contents_for_edit.each_with_index do |page_content, index| %>
  <div data-pwb-page-part="<%= page_content.page_part_key %>"
       <%= "data-pwb-page-part=#{page_content.page_part_key}".html_safe if params[:edit_mode] == 'true' %>>
    <% if page_content.is_rails_part %>
      <%= render partial: "pwb/components/#{page_content.page_part_key}", locals: {} rescue nil %>
    <% else %>
      <div class="prose ...">
        <%== @content_to_show[index] %>
      </div>
    <% end %>
  </div>
<% end %>
```

**Important**: 
- Edit mode marker only added if `params[:edit_mode] == 'true'`
- This adds a data attribute used by editor JavaScript

### Page Part Rendering

**Models**:
- `Pwb::PagePart`: Template container (Liquid templates or Rails partials)
- `Pwb::PageContent`: Join model connecting Page → PagePart
- `Pwb::Page`: Top-level page object

**PagePart Caching** (`/app/models/pwb/page_part.rb`):
```ruby
def template_content
  cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"
  Rails.cache.fetch(cache_key, expires_in: cache_duration) do
    load_template_content
  end
end
```

**Template Loading Priority**:
1. Database override (`self[:template]`)
2. Theme-specific file (`app/themes/{theme_name}/page_parts/{key}.liquid`)
3. Default file (`app/views/pwb/page_parts/{key}.liquid`)
4. Empty string fallback

### Property Page Rendering

**Controller**: `Pwb::PropsController#show_for_sale` / `#show_for_rent`
**Location**: `/app/controllers/pwb/props_controller.rb`

**Process**:
1. Find property by slug or ID (uses `Pwb::ListedProperty` materialized view)
2. Check fresh_response with HTTP caching (10 minutes)
3. Set property SEO data
4. Render theme-specific view

**No fragment caching** on property pages currently.

**Key Partials** (not cached):
- `/pwb/props/_images_section_carousel.html.erb`
- `/pwb/props/_extras.html.erb`
- `/pwb/props/_prop_info_list.html.erb`
- `/pwb/props/_prop_contact_info.html.erb`
- `/pwb/props/_request_prop_info.html.erb`

---

## 5. HTTP CACHING HEADERS

### Cache-Control Pattern

**Method**: `HttpCacheable#set_cache_control_headers` (lines 56-67)

**Format**:
```
Cache-Control: [public|private], max-age={seconds}, stale-while-revalidate={seconds}
```

**Default Values**:
- `max_age`: 5 minutes (configurable)
- `public_cache`: false (private by default)
- `stale_while_revalidate`: 1 hour

### ETag Support

**Location**: `HttpCacheable` included module (lines 24-25)
```ruby
etag { current_website&.id }
etag { I18n.locale }
```

**Built-in ETags**:
1. Website ID (tenant-scoped)
2. Current locale

**Combined with**: Record's `updated_at` timestamp (passed as option)

### Usage in Controllers

**Pages** (lines 39-43 of pages_controller.rb):
```ruby
set_cache_control_headers(
  max_age: 10.minutes,
  public: true,
  stale_while_revalidate: 1.hour
)
```

**Properties** (lines 20, 52 of props_controller.rb):
```ruby
return if fresh_response?(@property_details, max_age: 10.minutes, public: true)
```

### fresh_response? Method

**Purpose**: Check if response is fresh; returns 304 Not Modified if client cached version is valid

**Parameters**:
- `record_or_options`: Model instance or Hash of options
- `options`: Cache control options

**Behavior**:
1. Extracts ETag from record or option
2. Extracts last_modified from record.updated_at or option
3. Sets Cache-Control headers
4. Calls Rails' `fresh_when()` for conditional GET handling

---

## 6. WEBSITE LOCKING FEATURE (FUTURE COMPATIBILITY)

### Current Locking Implementation

**Location**: `/app/models/concerns/website/provisionable.rb`

**States** (lines 23-36):
- `pending` → `owner_assigned` → `agency_created` → `links_created` → 
- `field_keys_created` → `properties_seeded` → `ready` → 
- `locked_pending_email_verification` → `locked_pending_registration` → `live`
- Also: `failed`, `suspended`, `terminated`

**Locking Methods** (lines 205-213):
```ruby
def locked?
  locked_pending_email_verification? || locked_pending_registration?
end

def locked_mode
  return nil unless locked?
  return :pending_email_verification if locked_pending_email_verification?
  return :pending_registration if locked_pending_registration?
end
```

### Usage in ApplicationController

**Location**: `/app/controllers/pwb/application_controller.rb` (lines 86-98)

```ruby
def check_locked_website
  return unless @current_website&.locked?
  return unless request.path == '/' || request.path == root_path

  @locked_mode = @current_website.locked_mode
  @owner_email = @current_website.owner_email

  render 'pwb/locked/show', layout: 'pwb/locked', status: :ok
end
```

**Current Behavior**:
- Shows locked page only on root path
- Other URLs remain accessible
- Displays locked status to visitors

### Proposed Website Editing Lock

**Future Feature**: Lock website from editing during critical operations (e.g., during mass updates)

**Could Use Similar Pattern**:
```ruby
# Add to Website model
state :editing_locked  # prevents changes to content/pages/parts
state :editing_enabled # normal state

# Or use a flag
def editing_locked?
  editing_locked_until.present? && editing_locked_until > Time.current
end

attr_accessor :editing_locked_until  # timestamp
attr_accessor :editing_lock_reason   # string
```

---

## 7. RECOMMENDATIONS FOR FRAGMENT CACHING

### Cache Key Structure for Editable Views

**Proposed Format**:
```
pwb:w{website_id}:l{locale}:edit:{edit_mode}:{rest_of_key}
```

**Example**:
```
pwb:w123:l:en:edit:false:page:home:1234567890
pwb:w123:l:en:edit:true:page:home:1234567890  # Same page, different cache
```

**Or Simpler** (skip caching entirely in edit mode):
```ruby
if params[:edit_mode] != 'true'
  cache page_cache_key(@page) do
    # expensive rendering
  end
else
  # render without caching
end
```

### Recommended Caching Strategy

#### 1. **Never Cache in Edit Mode**
Simplest and safest approach:
```erb
<% if params[:edit_mode] != 'true' %>
  <% cache page_cache_key(@page) do %>
    <%= render 'shared/editable_section', page_content: @page_content %>
  <% end %>
<% else %>
  <%= render 'shared/editable_section', page_content: @page_content %>
<% end %>
```

**Pros**:
- Simple to understand and maintain
- No stale content served to editors
- No cache busting issues during editing

**Cons**:
- Every page edit request re-renders (acceptable for admin pages)

#### 2. **Separate Cache Key Based on Edit Mode**
For shared content viewed by both editors and visitors:
```ruby
# In helper
def editable_content_cache_key(content)
  edit_mode = params[:edit_mode] == 'true'
  cache_key_for(
    "editable",
    content.id,
    content.updated_at.to_i,
    "edit_#{edit_mode}"
  )
end
```

**Pros**:
- Allows caching of editor view (useful if many editors)
- Separate cache for visitor view

**Cons**:
- Double cache size
- More complex

#### 3. **User-Based Cache Keys** (Advanced)
```ruby
def editable_content_cache_key(content)
  cache_key_for(
    "editable",
    content.id,
    content.updated_at.to_i,
    "user_#{current_user&.id || 'visitor'}"
  )
end
```

**Pros**:
- More granular control
- Can tailor cache per role

**Cons**:
- Highest cache fragmentation
- May not be worth complexity

### Page Parts Caching

**Current State**: NOT fragment cached in views (only HTTP cached)

**Recommendation**:
```erb
<% cache page_part_cache_key(@page_content) do %>
  <div data-pwb-page-part="<%= @page_content.page_part_key %>"
       <%= "data-editable-part='true'".html_safe if params[:edit_mode] == 'true' %>>
    <% if @page_content.is_rails_part %>
      <%= render partial: "pwb/components/#{@page_content.page_part_key}", locals: {} rescue nil %>
    <% else %>
      <%== @content_html %>
    <% end %>
  </div>
<% end %>
```

**Cache Key**:
```ruby
def page_part_cache_key(page_content)
  return nil if page_content.blank?
  
  cache_key_for(
    "page_part",
    page_content.page_id,
    page_content.page_part_key,
    page_content.updated_at.to_i,
    page_content.content&.updated_at&.to_i || 0
  )
end
```

### Property Page Caching

**Current State**: HTTP cached only, no fragment cache

**Recommendation for Detail Pages**:
```erb
<% cache property_detail_cache_key(@property_details, "main") do %>
  <div class="property-title">
    <%= @property_details.title %>
  </div>
  <!-- other main content -->
<% end %>

<% cache property_detail_cache_key(@property_details, "gallery") do %>
  <%= render '/pwb/props/images_section_carousel' %>
<% end %>

<% cache property_detail_cache_key(@property_details, "contact") do %>
  <%= render '/pwb/props/request_prop_info' %>
  <%= render '/pwb/props/prop_contact_info' %>
<% end %>
```

**Benefits of Section-Level Caching**:
- Gallery can be cached independent of title updates
- Contact form only depends on agency contact changes
- Partial updates don't invalidate entire page cache

### Cache Invalidation Strategy

**Current Pattern**: Use `updated_at` timestamp in cache key

**For Editable Content**:
```ruby
# In PageContent model
after_update :clear_cache

def clear_cache
  cache_key = cache_key_for(
    "page_part",
    page_id,
    page_part_key,
    updated_at.to_i
  )
  # Note: updated_at already in key, so key changes automatically
  # No explicit deletion needed!
end
```

**For Properties**:
```ruby
# Already works via updated_at in cache key
# When prop.update! runs, prop.updated_at changes
# Next cache fetch gets new key → renders fresh content
```

---

## 8. EDIT MODE + CACHING COMPATIBILITY WITH WEBSITE LOCKING

### Problem Statement

When website locking feature is implemented, editable views must:
1. Respect the website lock (don't allow editing)
2. Not serve cached content to locked editors
3. Show lock status/message appropriately

### Solution Design

#### Add Locking State to Website

```ruby
# In Website model
class Website < ApplicationRecord
  # ... existing code ...

  # Editing lock state
  aasm column: :editing_lock_state, initial: :editing_enabled do
    state :editing_enabled
    state :editing_locked
  end

  # Lock reason and duration
  attr_accessor :editing_locked_reason
  attr_accessor :editing_locked_until  # timestamp

  def editing_locked?
    editing_locked? && editing_locked_until > Time.current
  rescue
    false
  end

  def lock_editing!(reason, duration = 1.hour)
    update!(
      editing_lock_state: :editing_locked,
      editing_locked_reason: reason,
      editing_locked_until: duration.from_now
    )
  end

  def unlock_editing!
    update!(editing_lock_state: :editing_enabled)
  end
end
```

#### Update Editor Access Check

```ruby
# In EditorController
def show
  # Check if website editing is locked
  if @current_website.editing_locked?
    @lock_message = @current_website.editing_locked_reason
    @unlock_time = @current_website.editing_locked_until
    render 'editing_locked', status: :locked
    return
  end

  # ... existing code ...
end
```

#### Fragment Cache + Lock Compatibility

```erb
<% 
  # Never cache editable content during edit mode
  # Lock state is implicit - if locked, editor doesn't see edit mode param
  cache_fragment = params[:edit_mode] != 'true' && !@current_website.editing_locked?
%>

<% if cache_fragment %>
  <% cache page_cache_key(@page) do %>
    <%= render 'shared/page_content', page: @page %>
  <% end %>
<% else %>
  <%= render 'shared/page_content', page: @page %>
<% end %>
```

#### Update Cache Invalidation on Lock

```ruby
# In Website model
def lock_editing!(reason, duration = 1.hour)
  update!(
    editing_lock_state: :editing_locked,
    editing_locked_reason: reason,
    editing_locked_until: duration.from_now
  )
  
  # Invalidate all fragment caches for this website
  # Use Redis pattern deletion in production
  cache_pattern = "#{Redis namespace}pwb:w#{id}:*"
  # Clear all caches for this website when locking
  Rails.cache.delete_matched("w#{id}/") if Rails.cache.respond_to?(:delete_matched)
end
```

#### Visitor Experience

```ruby
# Visitors always see cached, published version
# Locking website doesn't affect visitor cache

# Example cache key still works:
# pwb:w123:l:en:page:home:1234567890

# Visitors get cached version regardless of lock state
# Only admins/editors see lock message
```

---

## 9. AUDIT SUMMARY: KEY FINDINGS

| Aspect | Status | Details |
|--------|--------|---------|
| **Edit Mode Detection** | ⚠️ Insecure | URL param only, no auth enforcement (TODO in code) |
| **Edit Mode Persistence** | ❌ Not persistent | Request-level only, lost on navigation |
| **Fragment Caching** | ⚠️ Minimal | Only search result cards cached; pages/props use HTTP only |
| **Cache Store** | ✅ Mature | Redis + fallbacks, proper namespace/expiry |
| **Multi-tenant Keys** | ✅ Correct | Proper website_id + locale scoping |
| **Page Rendering** | ✅ Clean | Clear separation of content/edit data |
| **HTTP Caching** | ✅ Well-designed | ETag + Cache-Control headers implemented |
| **Website Locking** | ✅ Exists | Provisioning states, but for signup not editing |
| **Caching in Edit Mode** | ⚠️ Risk | HTTP caching still applies; could serve stale to editors |

---

## 10. IMPLEMENTATION ROADMAP

### Phase 1: Secure Edit Mode (Priority: HIGH)

```ruby
# 1. Enforce auth in EditorController
before_action :authenticate_admin_user!

def authenticate_admin_user!
  unless current_user && current_user.admin_for?(@current_website)
    redirect_to root_path, alert: "Not authorized"
  end
end
```

### Phase 2: Fragment Caching for Pages (Priority: MEDIUM)

```ruby
# 1. Add page_part_cache_key to CacheHelper
# 2. Wrap page content in cache blocks (skip if edit_mode)
# 3. Add after_update hooks for content invalidation
```

### Phase 3: Website Editing Lock (Priority: MEDIUM)

```ruby
# 1. Add editing_lock state to Website
# 2. Implement lock_editing! / unlock_editing! methods
# 3. Add EditorController check for lock state
# 4. Clear cache when lock activated
```

### Phase 4: Advanced Caching (Priority: LOW)

```ruby
# 1. Fragment cache property detail sections
# 2. Implement Russian doll caching (nested fragments)
# 3. Cache search results with proper invalidation
```

---

## 11. CONFIGURATION CHECKLIST FOR PRODUCTION

Before enabling fragment caching:

- [ ] Verify Redis connection and namespace ("pwb")
- [ ] Test cache expiry (default 1 hour in production)
- [ ] Confirm compression enabled for values > 1KB
- [ ] Verify reconnection logic (3 attempts configured)
- [ ] Test error handling (logs to Sentry if available)
- [ ] Implement auth checks before enabling edit mode
- [ ] Add lock state checks before allowing editing
- [ ] Monitor cache hit rates in production
- [ ] Set up alerts for high cache miss rates
- [ ] Document cache key conventions for team

---

## Related Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `/app/controllers/pwb/application_controller.rb` | 86-98 | Website lock checking |
| `/app/controllers/pwb/editor_controller.rb` | 13-26 | Edit mode param creation |
| `/app/controllers/pwb/pages_controller.rb` | 11-47 | Page rendering with HTTP cache |
| `/app/controllers/pwb/props_controller.rb` | 20, 52 | Property page HTTP caching |
| `/app/controllers/concerns/http_cacheable.rb` | Full | HTTP cache headers + ETags |
| `/app/helpers/cache_helper.rb` | Full | Fragment cache key generation |
| `/app/helpers/pwb/component_helper.rb` | 11 | Edit mode detection |
| `/app/models/pwb/current.rb` | Full | Tenant context (ActiveSupport::CurrentAttributes) |
| `/app/models/pwb/page_part.rb` | 66-71 | Template caching logic |
| `/app/models/pwb/page_content.rb` | Full | Join model (pages ↔ page_parts) |
| `/config/initializers/caching.rb` | Full | Cache store configuration |
| `/app/themes/barcelona/views/pwb/pages/show.html.erb` | Full | Page rendering with edit mode |
| `/app/views/pwb/search/_search_result_item.html.erb` | 1-77 | Only fragment-cached view currently |
