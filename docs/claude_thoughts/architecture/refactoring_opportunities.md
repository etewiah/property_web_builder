# PropertyWebBuilder Refactoring Opportunities

**Analysis Date:** 2025-12-17  
**Status:** Prioritized list of actionable refactoring opportunities

---

## 1. Duplicate SUPPORTED_LOCALES Configuration [HIGH PRIORITY]

**Issue:** Language configuration is duplicated across two files:
- `config/initializers/i18n_globalise.rb` - Has SUPPORTED_LOCALES (7 languages)
- `app/lib/pwb/config.rb` - Has SUPPORTED_LOCALES (25 languages)

The i18n_globalise.rb file is outdated and only covers: en, es, de, fr, nl, pt, it

**Files Involved:**
- `/config/initializers/i18n_globalise.rb` (lines 17-25)
- `/app/lib/pwb/config.rb` (lines 21-47)
- `/app/helpers/locale_helper.rb` (uses SUPPORTED_LOCALES)
- `/app/controllers/site_admin/website/settings_controller.rb` (references both)

**Impact:**
- Risk of inconsistency when adding new languages
- Developers may add languages to one file but not the other
- Init file defines I18n.available_locales as a subset

**Recommendation:**
1. Make `Pwb::Config::SUPPORTED_LOCALES` the single source of truth
2. Update `i18n_globalise.rb` to consume from Pwb::Config instead of maintaining its own list
3. Update i18n initialization to use: `I18n.available_locales = Pwb::Config::BASE_LOCALES` (which excludes regional variants)
4. Remove the redundant SUPPORTED_LOCALES definition from the initializer

**Effort:** 1-2 hours

---

## 2. Repeated Index/Search/Show Pattern in Site Admin Controllers [HIGH PRIORITY]

**Issue:** Multiple controllers follow nearly identical index/search/show patterns:

### Controllers with duplication:
- `/app/controllers/site_admin/contacts_controller.rb`
- `/app/controllers/site_admin/messages_controller.rb`
- `/app/controllers/site_admin/contents_controller.rb`
- `/app/controllers/site_admin/page_parts_controller.rb`
- `/app/controllers/site_admin/users_controller.rb`
- `/app/controllers/site_admin/pages_controller.rb` (slightly different ordering)

### Pattern Example:
```ruby
def index
  @items = Model.where(website_id: current_website&.id).order(created_at: :desc).limit(100)
  if params[:search].present?
    @items = @items.where('column ILIKE ?', "%#{params[:search]}%")
  end
end

def show
  @item = Model.where(website_id: current_website&.id).find(params[:id])
end
```

**Impact:**
- Code duplication across 6+ controllers
- Changes to search/filtering logic require updates in multiple places
- Inconsistent behavior (some use limit, some use pagination)
- Hard-coded limit values (100 vs others)

**Recommendation:**
Create a `SiteAdminIndexable` concern that extracts:
1. Index filtering with optional search
2. Show action with website_id scoping
3. Consistent pagination configuration
4. Optional before_action helpers for setup

**Example refactored concern:**
```ruby
# app/controllers/concerns/site_admin_indexable.rb
module SiteAdminIndexable
  extend ActiveSupport::Concern

  def default_index_scope
    @model_class.where(website_id: current_website&.id).order(created_at: :desc)
  end

  def search_index(scope, searchable_columns)
    return scope unless params[:search].present?
    
    query = "%#{params[:search]}%"
    conditions = searchable_columns.map { |col| "#{col} ILIKE ?" }
    scope.where(conditions.join(' OR '), *([query] * searchable_columns.length))
  end
end
```

**Effort:** 4-6 hours (to refactor 6+ controllers safely)

---

## 3. Hardcoded Locale Fields in API Serialization [MEDIUM PRIORITY]

**Issue:** API controllers manually hardcode all locale fields in serialization:

### Files:
- `/app/controllers/pwb/api/v1/properties_controller.rb` (lines 155-179, 30+ lines of hardcoded)
- `/app/controllers/pwb/api/v1/web_contents_controller.rb` (lines 87-111, 20+ lines of hardcoded)
- `/app/controllers/pwb/api/v1/lite_properties_controller.rb` (likely similar)

### Example hardcoding:
```ruby
def serialize_property_data(property)
  {
    attributes: {
      "title-en" => property.title_en,
      "description-en" => property.description_en,
      "title-es" => property.title_es,
      "description-es" => property.description_es,
      # ... hardcoded for 15+ locales
      "title-nl" => property.title_nl,
      "description-nl" => property.description_nl,
    }
  }
end
```

**Impact:**
- Adding a new language requires updates to 3+ serializers
- Brittle code if locale list changes
- Duplicates Pwb::Config::SUPPORTED_LOCALES logic
- Risk of missing a locale in one controller

**Recommendation:**
Create a `LocalizedSerializer` concern or service:
```ruby
module LocalizedSerializer
  def serialize_with_locales(object, attributes)
    data = { id: object.id.to_s, type: "objects" }
    
    Pwb::Config::SUPPORTED_LOCALES.each do |code, label|
      attributes.each do |attr|
        locale_suffix = code.parameterize(separator: '_')
        data["#{attr}-#{code}"] = object.send("#{attr}_#{locale_suffix}")
      end
    end
    data
  end
end
```

**Effort:** 2-3 hours

---

## 4. Complex View: Pages Edit with Inline JavaScript [MEDIUM PRIORITY]

**Issue:** Largest view file has significant complexity:

**File:** `/app/views/site_admin/pages/page_parts/edit.html.erb` (833 lines)

**Problems:**
- Multiple concerns mixed: page part ordering, visibility toggles, previews
- Likely contains duplicated JavaScript logic
- Hard to test or modify individual features
- Difficult to maintain responsive design

**Other large views with complexity:**
- Navigation settings tab (373 lines) - complex nested form
- Dashboard (349 lines) - mixing multiple data displays
- Property edit (263 lines) - multiple form sections

**Recommendation:**
1. Break into smaller component partials
2. Extract JavaScript into dedicated stimulus controller
3. Consider moving form building to view components or form objects

**Effort:** 6-8 hours (requires careful testing)

---

## 5. Manual Serialization Methods Scattered Across Controllers [MEDIUM PRIORITY]

**Issue:** 10+ controllers implement their own serialization logic:

### Controllers with serialize methods:
- `/app/controllers/pwb/api/v1/lite_properties_controller.rb`
- `/app/controllers/pwb/api/v1/properties_controller.rb`
- `/app/controllers/pwb/api/v1/web_contents_controller.rb`

### Problem:
- Each maintains its own format and structure
- No shared serialization standards
- API responses might be inconsistent
- Difficult to add common fields (pagination, metadata)

**Recommendation:**
Implement a proper serializer pattern:
1. Use `active_model_serializers` gem OR
2. Implement a simple serializer class pattern:
```ruby
# app/serializers/property_serializer.rb
class PropertySerializer
  def initialize(property)
    @property = property
  end

  def to_json
    # consistent format across all API endpoints
  end
end
```

**Effort:** 8-10 hours

---

## 6. Repeated Listing State Management Logic [MEDIUM PRIORITY]

**Issue:** Nearly identical code in SaleListing and RentalListing models:

### Files:
- `/app/models/pwb/sale_listing.rb` (lines 50-114)
- `/app/models/pwb/rental_listing.rb` (lines 52-122)

### Duplicated Methods:
- `activate!` - identical logic
- `deactivate!` - identical implementation
- `archive!` - same validation and update
- `unarchive!` - same update
- `can_destroy?` - identical check
- `only_one_active_per_realty_asset` - identical validation
- `cannot_delete_active_listing` - same logic
- `deactivate_other_listings` - identical
- `ensure_active_listing_visible` - same
- `refresh_properties_view` - identical

**Impact:**
- Bug fixes need to be made in two places
- Inconsistent behavior if one is updated and other isn't
- Violates DRY principle
- 60+ lines of duplicated code

**Recommendation:**
Create a `ListingStateable` concern:
```ruby
# app/models/concerns/listing_stateable.rb
module ListingStateable
  extend ActiveSupport::Concern

  included do
    validate :only_one_active_per_realty_asset, if: :active?
    validate :cannot_delete_active_listing, on: :destroy
    before_save :deactivate_other_listings, if: :will_activate?
    after_save :ensure_active_listing_visible, if: :saved_change_to_active?
    after_commit :refresh_properties_view
  end

  def activate!
    transaction do
      listings_of_same_type.where.not(id: id).update_all(active: false)
      update!(active: true, archived: false)
    end
  end

  # ... other shared methods

  private

  def listings_of_same_type
    # Subclass implements this to return sale_listings or rental_listings
    raise NotImplementedError
  end
end
```

Then in each listing:
```ruby
class SaleListing < ApplicationRecord
  include ListingStateable
  
  private
  def listings_of_same_type
    realty_asset.sale_listings
  end
end
```

**Effort:** 3-4 hours

---

## 7. Manual Website_ID Scoping in Controllers [LOW PRIORITY]

**Issue:** Multiple controllers manually handle `website_id` scoping:

### Pattern:
```ruby
Model.where(website_id: current_website&.id).find(params[:id])
```

### Controllers doing this:
- `/app/controllers/site_admin/contacts_controller.rb` (line 22)
- `/app/controllers/site_admin/messages_controller.rb` (line 21)
- `/app/controllers/site_admin/contents_controller.rb` (line 19)
- `/app/controllers/site_admin/page_parts_controller.rb` (line 19)
- `/app/controllers/site_admin/pages_controller.rb` (line 60)
- `/app/controllers/site_admin/users_controller.rb` (line 19)

**Note:** This is mitigated by `ActsAsTenant` in base controller, but Pwb:: models are intentionally not scoped

**Impact:**
- Repetitive code in before_actions
- Potential security issue if someone forgets the scoping
- Controller code becomes verbose

**Recommendation:**
Create a `SiteAdminResourceable` concern for find operations:
```ruby
module SiteAdminResourceable
  extend ActiveSupport::Concern

  def set_scoped_resource(model_class, param: :id)
    @resource = model_class.where(website_id: current_website&.id).find(params[param])
  end
end
```

**Effort:** 1-2 hours (low complexity)

---

## 8. Image Gallery Handling: Repeated Query Patterns [LOW PRIORITY]

**Issue:** `/app/controllers/site_admin/images_controller.rb` (lines 11-71)

Complex image aggregation logic joins multiple photo types with similar patterns:
- ContentPhoto via join
- WebsitePhoto via association
- PropPhoto via join

**Pattern repeats 3 times:**
```ruby
photos.each do |photo|
  next unless photo.image.attached?
  begin
    images << { id: "...", type: '...', url: url_for(...), ... }
  rescue StandardError => e
    Rails.logger.warn "Error processing..."
  end
end
```

**Recommendation:**
Extract into a service class:
```ruby
# app/services/image_gallery_builder.rb
class ImageGalleryBuilder
  def initialize(website)
    @website = website
  end

  def build_gallery
    images = []
    images.concat(content_photos)
    images.concat(website_photos)
    images.concat(property_photos)
    images
  end

  private

  def content_photos
    # Extract the repeated pattern here
  end
end
```

**Effort:** 2-3 hours

---

## 9. Export/Import Controllers Lack Consistency [LOW PRIORITY]

**Issue:** Export and import operations scattered across:
- `/app/controllers/pwb/export/properties_controller.rb`
- `/app/controllers/pwb/import/properties_controller.rb`
- `/app/controllers/pwb/export/web_contents_controller.rb`
- `/app/controllers/pwb/import/web_contents_controller.rb`
- Models like Pwb::Content with `import()` and `to_csv()` methods

**Problems:**
- No unified interface or error handling
- CSV export logic in model, import in controller
- Hard-coded field lists scattered across code
- No progress tracking for large imports

**Recommendation:**
Create an `ImportExportService` base class or separate service objects for each resource

**Effort:** 4-6 hours

---

## Summary

### Refactoring Priority Order

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 1 | Merge SUPPORTED_LOCALES configs | 1-2h | Prevents bugs, single source of truth |
| 2 | Extract SiteAdminIndexable concern | 4-6h | Removes 100+ lines of duplication |
| 3 | Consolidate Listing state logic (concern) | 3-4h | Removes 60+ lines, easier maintenance |
| 4 | Generalize locale serialization | 2-3h | Makes adding languages painless |
| 5 | Extract SiteAdminResourceable concern | 1-2h | Small but improves security pattern |
| 6 | Break up large view files | 6-8h | Improves maintainability, harder to test |
| 7 | Implement serializer pattern | 8-10h | Better API consistency and flexibility |
| 8 | Extract image gallery service | 2-3h | Simplifies controllers, testable code |
| 9 | Unify import/export operations | 4-6h | Better UX, consistent patterns |

### Total Estimated Effort
**~32-44 hours** for all refactoring opportunities (phased over multiple sprints)

### Recommended Approach
1. Start with **High Priority** items (config + controller duplication)
2. Continue with **Medium Priority** items (serialization, state logic)
3. Handle **Low Priority** items as tech debt during slower periods

---

**Generated for PropertyWebBuilder development team**
