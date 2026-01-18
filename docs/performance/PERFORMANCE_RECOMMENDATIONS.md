## Performance Recommendations

Documenting a few concrete wins that fit within the existing architecture without requiring a platform change.

### 1. Index `prop_state_key`

* Why: `Searchable::property_state` (`app/models/concerns/listed_property/searchable.rb:114-126`) filters the `pwb_properties` materialized view by `prop_state_key`. Without an index, every state-filtered request scans the wide UUID-backed view, which slows down paginated listing pages and search facets.
* Recommendation: Add a btree index on `prop_state_key` (optionally combined with `website_id` to keep tenant queries lean). Example migration:
  ```ruby
  add_index :pwb_properties, [:website_id, :prop_state_key], name: 'index_pwb_properties_on_website_id_and_prop_state_key'
  ```
* Verify: Measure query plan for `WHERE prop_state_key = ?` before/after and rerun a representative search request.

### 2. Keep facet counts in the database

* Why: `SearchFacetsService` currently plucks all `scope` IDs into Ruby and then queries `Feature.where(realty_asset_id: property_ids)` (`app/services/pwb/search_facets_service.rb:48-85`). Large result sets materialize heavy arrays and prevent Postgres from using indexes to limit the work.
* Recommendation: Push the ID selection into the DB using `Feature.where(realty_asset_id: scope.select(:id))` or by joining `Feature` directly against the filtered `ListedProperty` relation. This keeps counting inside Postgres, reduces Ruby memory pressure, and benefits from existing indexes on `pwb_features.realty_asset_id`.
* Verify: Run `EXPLAIN ANALYZE` on the existing counts and confirm the new query avoids a large sequential scan or Ruby-level materialization.

### 3. Consolidate property count cache misses

* Why: `CacheService.property_counts` (`app/services/cache_service.rb:45-60`) issues five `count` queries on the same `Pwb::ListedProperty` scope whenever the cache expires. Even with Redis caching, each miss takes multiple table scans for totals that can be aggregated.
* Recommendation: Replace the five counts with a single aggregated query (e.g., `scope.group(:for_sale, :for_rent, :visible, :highlighted).count`) or persist the counts in a counter table that updates via callbacks/batch jobs. The existing cache invalidation hooks (like `RefreshPropertiesViewJob`) can flush the cache whenever relevant writes happen.
* Verify: Run the new query in a console and compare its execution time/plan to the current approach, then monitor cache hit rates during a deployment.

## Next Steps

1. Ship the migration for `prop_state_key` and deploy it with a lock-free creation strategy (`CONCURRENTLY` if the table is live).
2. Refactor `SearchFacetsService` to avoid `pluck(:id)` materialization, updating tests if necessary.
3. Update `CacheService.property_counts` to use a single aggregate and review the invalidation hooks to ensure they cover the new structure.
