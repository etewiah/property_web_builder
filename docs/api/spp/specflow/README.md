# SPP-PWB Integration — SpecFlow

Development planning documents for the SPP-PWB integration, following the [SpecFlow methodology](https://github.com/specstoryai/specflow).

## Documents

| Document | Phase | Purpose |
|----------|-------|---------|
| [SPEC.md](./SPEC.md) | Intent | Vision, success criteria, constraints, non-goals |
| [TASKS.md](./TASKS.md) | Tasks | 6 phases, 15 tasks with input/action/output/verification |

## Architecture Reference

Detailed architecture docs live one level up in [`docs/api/spp/`](../README.md):

- [SppListing Model](../spp-listing-model.md) — Data model, schema, migration
- [Endpoints](../endpoints.md) — API specs (publish, unpublish, leads)
- [Authentication](../authentication.md) — API key auth
- [CORS](../cors.md) — Cross-origin configuration
- [SEO](../seo.md) — Canonical URLs, sitemaps, JSON-LD
- [Data Freshness](../data-freshness.md) — Caching strategy

## Phase Summary

| Phase | Tasks | Dependencies | Focus |
|-------|-------|-------------|-------|
| 1. Data Model | 1.1–1.4 | None | SppListing migration, model, factory, specs |
| 2. Endpoints | 2.1–2.5 | Phase 1 | Publish, unpublish, leads + enquiry linking |
| 3. CORS + Auth | 3.1–3.2 | None | CORS config, API key provisioning |
| 4. SEO | 4.1–4.4 | Phase 1 | Canonical URLs, sitemaps, JSON-LD |
| 5. Cache TTL | 5.1 | None | Reduce API cache for fresher data |
| 6. Content Mgmt | 6.1 | Phases 1+2 | SppListing update endpoint |
