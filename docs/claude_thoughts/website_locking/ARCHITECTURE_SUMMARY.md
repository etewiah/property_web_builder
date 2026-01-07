# Website Locking Feature - Architecture Summary

## Quick Reference

### What is Website Locking?
A feature where an entire PropertyWebBuilder website gets **pre-compiled into static HTML** and served from the database, making pages immutable and blazingly fast. No more dynamic rendering, no database queries on each request.

### Current State
- ✓ Dynamic rendering on every request (10 min cache headers)
- ✓ Liquid templates + block_contents (JSON) render on-demand
- ✓ HTTP caching layer (ETags, Cache-Control headers)
- ✓ PaletteCompiler shows precedent for this pattern

### Proposed State (Locked)
- ✓ Pre-compiled HTML stored in database
- ✓ No rendering, no DB queries (except compiled_pages lookup)
- ✓ 30-day cache headers (max-age)
- ✓ Write-protected (no content changes allowed)
- ✓ Can be unlocked to return to dynamic mode

---

## Architecture Overview

### Three-Layer Approach

```
Layer 1: COMPILATION (One-time)
├─ PageCompiler service
├─ Renders all pages with their Liquid templates
├─ Stores in CompiledPage table
└─ Marks website as locked_mode = true

Layer 2: STORAGE (Database)
├─ CompiledPage table
│  ├─ compiled_html (text)
│  ├─ metadata (JSON)
│  └─ locale (for i18n)
└─ Website.locked_mode boolean flag

Layer 3: SERVING (Request-time)
├─ PagesController checks: locked_mode? && compiled_page?
├─ Yes → Serve compiled HTML (5ms response)
├─ No → Use dynamic rendering (100ms response)
└─ Aggressive cache headers when locked
```

### Data Model Changes

**New Table: pwb_compiled_pages**
```
id              (primary key)
website_id      (FK to pwb_websites) [indexed]
page_slug       (string) "home", "about", etc.
locale          (string) "en", "es", "fr"
compiled_html   (text) Full rendered HTML
metadata        (jsonb) {title, seo_title, meta_description, ...}
created_at, updated_at
```

**Updated Table: pwb_websites**
```
locked_mode           (boolean, default: false)
locked_pages_updated_at (datetime, nullable)
```

---

## Key Components

### 1. PageCompiler Service (~200 LOC)
```ruby
Pwb::PageCompiler.new(website).compile_all_pages
# Iterates through all visible pages
# For each page, for each locale:
#   - Renders with Liquid templates
#   - Stores pre-rendered HTML
#   - Stores metadata
```

### 2. CompiledPage Model (~40 LOC)
```ruby
Pwb::CompiledPage
# Stores pre-compiled HTML
# Provides find_for_rendering(website_id, page_slug, locale)
# Unique constraint on [website_id, page_slug, locale]
```

### 3. Website Extensions (~30 LOC)
```ruby
website.lock_website    # Compile all pages
website.unlock_website  # Delete compiled pages
website.locked_mode?    # Check if locked
website.find_compiled_page(slug, locale)
```

### 4. PagesController Modification (~20 LOC)
```ruby
def show_page
  if @current_website.locked_mode?
    compiled = @current_website.find_compiled_page(...)
    if compiled
      set_aggressive_cache_headers
      return render inline: compiled.compiled_html
    end
  end
  # ... fall back to dynamic rendering
end
```

### 5. Content Change Validations (~30 LOC)
```ruby
# Add to PageContent, PagePart, Content models:
validate :validate_not_locked
  # Prevents modifications when website.locked_mode = true
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Create CompiledPage model
- [ ] Create PageCompiler service
- [ ] Add migration (locked_mode, compiled_pages table)
- [ ] Modify PagesController to check for compiled HTML
- [ ] Write unit tests

### Phase 2: Admin UI & API (Week 2)
- [ ] Add lock/unlock buttons to website admin
- [ ] Create API endpoints for locking
- [ ] Display locking status
- [ ] Add validations to prevent edits when locked

### Phase 3: Refinement (Week 3)
- [ ] Handle edge cases (Rails parts, i18n)
- [ ] Optimize cache headers
- [ ] Background job for async compilation
- [ ] Monitoring/metrics

### Phase 4: Documentation & Training (Week 4)
- [ ] User documentation
- [ ] Admin guide
- [ ] Performance benchmarks
- [ ] Release notes

---

## Technical Highlights

### Precedent: PaletteCompiler Pattern
This feature follows the exact pattern of the existing PaletteCompiler:

| Aspect | PaletteCompiler | PageCompiler |
|--------|-----------------|--------------|
| Input | style_variables | page content |
| Process | Generate CSS | Render templates |
| Output | CSS string | HTML string |
| Storage | compiled_palette_css col | CompiledPage table |
| Toggle | palette_mode field | locked_mode field |
| Usage | Serve compiled CSS | Serve compiled HTML |

### Performance Impact

**Before (Dynamic Rendering)**
- Response time: 80-150ms
- Cache: 10 minutes (with stale-while-revalidate)
- Each request: DB query + template rendering

**After (Locked)**
- Response time: 5-10ms
- Cache: 30 days
- Each request: Single DB lookup, render inline HTML

**Improvement: 10-15x faster** (for locked pages)

### Multi-Tenancy Safety
- Compilation happens per website
- Respects database_shard configuration
- No cross-tenant data sharing
- Each website controls its own locked state

### Backward Compatibility
- Existing dynamic rendering untouched
- Locking is opt-in (feature flag)
- Can unlock anytime to return to dynamic
- No breaking changes to existing code

---

## Design Decisions

### Why Store Compiled HTML in Database?
**Alternatives Considered:**
- ❌ Static files on disk - No, harder to track, CDN issues
- ❌ Redis cache - No, doesn't persist across deploys
- ❌ Memcached - No, not persistent
- ✓ Database - Yes, persistent, queryable, easy to manage

### Why Allow Unlock?
**Flexibility for:**
- Bug fixes (find issue, unlock, fix, recompile)
- Theme changes (update theme, unlock, update, recompile)
- Content urgency (unlock, update, recompile)
- Testing (lock/unlock to validate process)

### Why Validations (Not Rendering Errors)?
**Because:**
- Early feedback to admins
- Prevents accidental data corruption
- Clear error messages
- Encourages proper workflow (unlock → edit → recompile)

### Why Liquid Compilation Only (Not Rails Parts)?
**Because:**
- Rails parts (forms, maps, search) are inherently dynamic
- They fetch data at request time
- Can't be meaningfully pre-compiled
- Solution: Either skip them or show placeholders

---

## Testing Strategy

### Unit Tests
- [ ] PageCompiler renders pages correctly
- [ ] CompiledPage model CRUD
- [ ] Website.lock_website/unlock_website
- [ ] Validation prevents edits when locked

### Integration Tests
- [ ] End-to-end lock → serve → unlock
- [ ] Locale-specific compilation
- [ ] Cache header verification
- [ ] Rails parts handling

### Performance Tests
- [ ] Response time with/without locking
- [ ] Compilation duration for 10/50/100 pages
- [ ] Memory usage of compiled HTML storage
- [ ] Query count reduction

### E2E Tests
- [ ] Admin can lock/unlock website
- [ ] Locked pages serve compiled HTML
- [ ] Editing is prevented when locked
- [ ] Unlocking restores dynamic behavior

---

## Monitoring & Observability

### Metrics to Track
```
- websites.locked_count (gauge)
- pages.compiled_total (gauge per website)
- compilation.duration_seconds (histogram)
- compiled_page.response_time (histogram)
- lock.requests_total (counter)
- unlock.requests_total (counter)
```

### Logging Events
```
compile_start    - Website #{id}: starting compilation
compile_success  - Website #{id}: compiled N pages in Xs
compile_failure  - Website #{id}: failed - #{error}
lock_start       - Website #{id}: locking
lock_success     - Website #{id}: locked
unlock_start     - Website #{id}: unlocking
unlock_success   - Website #{id}: unlocked
```

### Alerts
```
- Compilation takes > 5 minutes
- Compilation fails for website
- Locked website has < compiled pages than expected
- Cache hit rate drops below 90%
```

---

## Questions & Answers

**Q: What about property pages? Should they be locked?**
A: No, property detail pages should remain dynamic. Only CMS pages lock.

**Q: What if I need to fix a typo on a locked page?**
A: Unlock → edit → recompile. Or create a new version strategy.

**Q: Can I lock only some pages, not all?**
A: Yes, add a per-page `locked` boolean to Page model if needed.

**Q: What about home page with dynamic property carousel?**
A: Three options:
   1. Show property snapshot from lock time
   2. Keep home page unlocked (compile other pages)
   3. Embed latest 5 properties in compilation

**Q: Does this work with external feeds (Airbnb, MLS, etc.)?**
A: Current external feeds are fetched at request time. When locked, show last-known snapshot. External feeds and locking are incompatible (by design).

**Q: How do translations work?**
A: Compile separately per locale. Store each locale in CompiledPage.locale.

**Q: What about the 30-day cache expiry?**
A: Can be configured per website. Or use shorter TTL with cache revalidation.

**Q: Can I programmatically lock/unlock via API?**
A: Yes, endpoints: `POST /api/websites/:id/lock`, `POST /api/websites/:id/unlock`

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Compilation takes too long | Run as background job, allow partial locking |
| Stale content served | Monitor freshness, allow manual recompile |
| Bug in compilation breaks pages | Test in staging, maintain unlock ability |
| Rails parts break when locked | Skip or render placeholders |
| Large HTML bloats database | Compression, separate storage, cleanup |
| Admins accidentally lock | Confirmation dialogs, permissions |
| Theme changes with locked site | Auto-unlock when theme changes |
| Locale mismatches | Compile for all active locales |

---

## Files & Estimates

### New Files (~500 LOC)
- `app/models/pwb/compiled_page.rb` (~40 LOC)
- `app/services/pwb/page_compiler.rb` (~200 LOC)
- `app/controllers/site_admin/website_locking_controller.rb` (~100 LOC)
- `app/views/site_admin/website_locking/*` (~80 LOC)
- `lib/tasks/websites.rake` (~100 LOC)

### Modified Files (~150 LOC)
- `app/models/pwb/website.rb` (+30 LOC)
- `app/models/pwb/page_content.rb` (+10 LOC)
- `app/models/pwb/page_part.rb` (+10 LOC)
- `app/models/pwb/content.rb` (+10 LOC)
- `app/controllers/pwb/pages_controller.rb` (+30 LOC)
- `config/routes.rb` (+10 LOC)
- `db/migrate/*_add_website_locking.rb` (~40 LOC)

### Tests (~600 LOC)
- `spec/services/pwb/page_compiler_spec.rb` (~200 LOC)
- `spec/models/pwb/compiled_page_spec.rb` (~100 LOC)
- `spec/models/pwb/website_spec.rb` (+100 LOC)
- `spec/controllers/pwb/pages_controller_spec.rb` (+100 LOC)
- `spec/requests/site_admin/website_locking_spec.rb` (~100 LOC)

**Total: ~1,250 LOC** (reasonable for the feature)

---

## Success Criteria

After implementation, we should be able to:

1. ✓ Lock a website with one action
2. ✓ Serve locked pages 10-15x faster
3. ✓ Prevent content changes when locked
4. ✓ Unlock and return to dynamic rendering
5. ✓ Support multiple locales
6. ✓ Cache for 30+ days without staleness
7. ✓ Gracefully skip/handle Rails parts
8. ✓ Monitor compilation and serving
9. ✓ Pass 100% test coverage
10. ✓ Document for admins and developers

---

## Related Documentation

- [Full Architecture Investigation](./website_locking_architecture_investigation.md)
- [Rendering Pipeline Diagrams](./rendering_pipeline_diagram.md)
- [Code Examples & Implementation](./website_locking_code_examples.md)

---

## Approved By

- [ ] Engineering Lead
- [ ] Product Manager
- [ ] DevOps/Infrastructure
- [ ] QA Lead

**Date Created:** January 7, 2026  
**Last Updated:** January 7, 2026  
**Status:** Architecture Phase
