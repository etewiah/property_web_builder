# Deprecated Features

This document tracks features that have been deprecated and removed from PropertyWebBuilder.

## RETS/MLS Integration (Removed December 2024)

### What was it?
RETS (Real Estate Transaction Standard) integration allowed synchronizing property listings from MLS (Multiple Listing Service) databases. This was an experimental feature that was never fully implemented or tested in production.

### Why was it removed?
- The feature was experimental and never actively used
- The `rets` gem (v0.11.2) was constraining other gem updates
- RETS protocol is being phased out industry-wide in favor of RESO Web API
- Maintaining untested, unused code increases technical debt

### Affected files
The following files contain deprecated RETS code (kept for reference):

| File | Purpose | Status |
|------|---------|--------|
| `app/services/pwb/mls_connector.rb` | RETS client wrapper | Deprecated, raises NotImplementedError |
| `app/services/pwb/import_mapper.rb` | MLS field mapping | Deprecated |
| `app/models/pwb/import_source.rb` | RETS source definitions | Deprecated data |
| `app/controllers/pwb/import/mls_controller.rb` | MLS API endpoint | Deprecated |

### Alternatives
If you need MLS/property data integration, consider:

1. **RESO Web API** - The modern replacement for RETS
   - More RESTful, JSON-based API
   - Better supported by MLS providers

2. **Third-party MLS services**
   - Spark API (FBS)
   - Bridge Interactive
   - ListHub

3. **CSV/XML import**
   - Manual or scheduled file-based imports
   - Existing property import functionality still works

4. **Property aggregation services**
   - Zillow API
   - Realtor.com API
   - Local MLS data feeds

### Migration path
If you were using RETS integration (unlikely as it was experimental):

1. Export any MLS-sourced property data
2. Set up alternative data source (see above)
3. Use existing CSV import or API integration
4. Remove deprecated files in a future cleanup release

### Related documentation updates
The following documentation files reference RETS and have been noted as containing outdated information:

- `CHANGELOG.md` - Historical reference (kept)
- `README.md` - Roadmap item (should be updated)
- `docs/planning/*.md` - Planning docs (historical reference)
- `docs/claude_thoughts/testing/*.md` - Test plans (outdated)

---

## Other Deprecated Features

### OData Integration (Previously Removed)
- Removed before Dec 2024
- `ruby_odata` gem no longer supported
- Referenced in `app/models/pwb/import_source.rb` comment

### Vue.js Frontend (Deprecated)
- Location: `app/frontend/`
- See: `app/frontend/DEPRECATED.md`
- Replaced by: Server-rendered ERB + Stimulus.js

### GraphQL API (Deprecated)
- Location: `app/graphql/`
- See: `app/graphql/DEPRECATED.md`
- Replaced by: REST API endpoints

### Bootstrap CSS (Deprecated)
- Location: `vendor/assets/stylesheets/bootstrap/`
- See: `vendor/assets/stylesheets/bootstrap/DEPRECATED.md`
- Replaced by: Tailwind CSS
