# Page Parts Test Coverage Analysis

## Summary

The missing page part template error (thrown in `rebuild_page_content`) was not caught by tests because:

1. **Seeding tests don't validate template existence** - The `pages_seeder_spec.rb` runs the seeding process but doesn't verify that templates actually exist
2. **rebuild_page_content has weak validation** - It only checks `page_part.template` (the database field), not the fallback file system sources
3. **No end-to-end template validation** - Tests don't verify that the template lookup chain works correctly
4. **Seeding process lacks error handling** - Missing templates silently return empty strings, allowing invalid state to persist

## Current Test Coverage

### Existing Tests

#### 1. **PagePartManager Specs** (`spec/services/pwb/page_part_manager_spec.rb`)
- **What it tests:**
  - `find_or_create_content()` - Creates or finds content containers
  - `seed_container_block_content()` - Seeds content with locale-specific data
  - Multi-website support
  
- **Gaps:**
  - Does NOT test `rebuild_page_content()` method
  - Does NOT validate template existence
  - Tests use factory-created page parts with templates already set
  - No test for missing template error

#### 2. **PagePart Model Specs** (`spec/models/pwb/page_part_spec.rb`)
- **What it tests:**
  - `template_content()` method with all three fallback sources
  - Cache behavior and invalidation
  - Template priority (database > theme file > default file)
  
- **Strengths:**
  - Comprehensive testing of template loading hierarchy
  - Tests cache functionality
  - Tests all fallback scenarios
  
- **Gaps:**
  - Does NOT test integration with `rebuild_page_content()`
  - Doesn't test what happens when rebuild_page_content calls `.template`
  - Factory creates templates, doesn't test real seeded data

#### 3. **PagesSeeder Specs** (`spec/libraries/pwb/pages_seeder_spec.rb`)
- **What it tests:**
  - Calls `seed_page_parts!()`, `seed_page_basics!()`, `seed_page_content_translations!()`
  - Verifies content is created with correct values
  - Tests visibility and sort order
  
- **Critical Gap:**
  - Does NOT validate that page parts have valid templates before seeding content
  - Tests assert on content existence but not template validity
  - Uses `before(:all)` global setup - templates exist in test environment

#### 4. **PagePartDefinition Specs** (`spec/lib/pwb/page_part_definition_spec.rb`)
- **What it tests:**
  - Field definitions and validation
  - Template field validation (warns about missing fields)
  - Registry functionality
  
- **Gaps:**
  - Only tests presence of template files, not integration with PagePartManager
  - Doesn't test seeding workflow

#### 5. **SeedRunner Specs** (`spec/lib/pwb/seed_runner_spec.rb`)
- **What it tests:**
  - Different seeding modes (create_only, force_update, upsert)
  - Multi-tenancy isolation
  - Dry-run functionality
  
- **Major Gap:**
  - Uses mocks and stubs instead of actual seeding
  - Line 13-14: `allow_any_instance_of(described_class).to receive(:seed_translations)` and `seed_pages` are mocked
  - Does NOT actually execute seeding process

### Test Files Related to Page Parts

```
/Users/etewiah/dev/sites-older/property_web_builder/spec/services/pwb/page_part_manager_spec.rb
/Users/etewiah/dev/sites-older/property_web_builder/spec/models/pwb/page_part_spec.rb
/Users/etewiah/dev/sites-older/property_web_builder/spec/libraries/pwb/pages_seeder_spec.rb
/Users/etewiah/dev/sites-older/property_web_builder/spec/lib/pwb/page_part_definition_spec.rb
/Users/etewiah/dev/sites-older/property_web_builder/spec/lib/pwb/seed_runner_spec.rb
/Users/etewiah/dev/sites-older/property_web_builder/spec/lib/tasks/pwb_update_seeds_spec.rb
/Users/etewiah/dev/sites-older/property_web_builder/spec/requests/pwb/editor/page_parts_spec.rb
```

## Root Cause Analysis

### The Error Location

**File:** `app/services/pwb/page_part_manager.rb`, line 173-176

```ruby
def rebuild_page_content(locale)
  unless page_part && page_part.template
    raise "page_part with valid template not available"
  end
```

### Why It Failed in Production

1. **Page part YML seed files DO have templates:**
   - Example: `db/yml_seeds/page_parts/home__landing_hero.yml` contains a `template:` field
   - When loaded by `PagesSeeder.seed_page_parts!()`, the template is saved to the database

2. **But the new code path uses `template_content()` instead of `.template`:**
   - The `PagePart.template_content` method (added in commit 1d428f10) has proper fallback logic
   - It returns empty string `''` if no template found anywhere
   - The check `page_part && page_part.template` only checks the database field

3. **The check doesn't use `template_content()`:**
   - `rebuild_page_content()` uses `page_part.template` directly
   - It doesn't call `template_content()` which has the fallback chain
   - So it fails when database template is nil but file-based templates exist

### Why Tests Didn't Catch It

1. **PagePartManager spec:**
   - Factory creates page parts with explicit templates: `template { "<p>{{ page_part['main_content']['content'] %} }}</p>" }`
   - Never tests empty database template with files on disk
   - Never calls `rebuild_page_content()` with missing database template

2. **PagesSeeder spec:**
   - Seeds from YAML files which DO have templates in the database
   - Doesn't test theme-specific template files
   - All templates exist in the database from seeding, so check passes

3. **PagePart spec:**
   - Tests `template_content()` thoroughly
   - But doesn't test how `rebuild_page_content()` works with it
   - Tests are isolated from `PagePartManager` integration

4. **SeedRunner spec:**
   - Actually mocks out the seeding methods entirely (lines 13-14)
   - Never executes real seeding
   - So template issues never surfaced

## The Code Flow Problem

### What Happens on New Websites with Themes

1. New website created with theme: `bristol`
2. `PagesSeeder.seed_page_parts!()` runs:
   - Loads YAML files from `db/yml_seeds/page_parts/`
   - Creates `Pwb::PagePart` records with `template:` field from YAML
   - BUT: The YAML might have been created for a different theme

3. When seeding content: `ContentsSeeder.seed_page_content_translations!()`
   - Calls `page_part_manager.seed_container_block_content()` (line 85)
   - Which calls `rebuild_page_content()` (line 124 in PagePartManager)
   - Which checks `page_part && page_part.template` (line 174)

4. If template was null/empty in YAML or database:
   - Check fails
   - Raises error
   - Content seeding stops

### Why Bristol Theme Failed

The `bristol` theme was added without corresponding page part templates:
- Page parts were seeded from generic YML
- The YML may not have had templates, or templates were for `default` theme
- When seeding content for `bristol`, templates weren't available
- `rebuild_page_content()` tried to use database template, found nothing
- Error was raised

## Specific Test Coverage Gaps

### 1. rebuild_page_content() is Never Tested
**Location:** `spec/services/pwb/page_part_manager_spec.rb`

Currently tests:
- `find_or_create_content()` ✓
- `seed_container_block_content()` ✓

Missing:
- `rebuild_page_content()` ✗
- Template validation during seeding ✗
- Error handling for missing templates ✗

### 2. YAML Seed File Validation is Missing
**Location:** None

No tests validate that:
- All referenced page parts in YAML exist
- Templates in YAML are valid Liquid templates
- Template fields aren't empty for non-rails-parts
- Theme-specific templates exist when needed

### 3. Seeding Process is Mocked, Not Real
**Location:** `spec/lib/pwb/seed_runner_spec.rb`, lines 13-14

```ruby
allow_any_instance_of(described_class).to receive(:seed_translations)
allow_any_instance_of(described_class).to receive(:seed_pages)
```

Should be:
- Real seeding execution
- Verification of output state
- End-to-end validation

### 4. Multi-Tenant Template Loading is Untested
**Location:** None

No tests for:
- Theme-specific page part templates (e.g., `app/themes/bristol/page_parts/landing_hero.liquid`)
- Fallback chain when theme templates missing
- Correct theme selected based on website's `theme_name`

## Recommendations for Improving Test Coverage

### 1. **Add Template Validation Tests to PagePartManager Spec**
```ruby
describe "#rebuild_page_content" do
  context "when template exists in database" do
    it "uses database template" do
      page_part.update(template: "<div>{{ page_part['field']['content'] }}</div>")
      result = page_part_manager.rebuild_page_content("en")
      expect(result).to include("<div>")
    end
  end
  
  context "when template is missing from database" do
    it "raises error" do
      page_part.update(template: nil)
      expect {
        page_part_manager.rebuild_page_content("en")
      }.to raise_error("page_part with valid template not available")
    end
  end
  
  context "when theme-specific template exists" do
    it "uses theme template as fallback" do
      # This should work but currently doesn't because rebuild_page_content
      # doesn't use template_content() fallback chain
    end
  end
end
```

### 2. **Add YAML Seed File Validation**
Create a new spec file: `spec/lib/pwb/page_part_seed_validator_spec.rb`

```ruby
describe Pwb::PagePartSeedValidator do
  it "validates all page part YML files" do
    # Check each YAML file in db/yml_seeds/page_parts/
    # Verify:
    # - Has page_part_key
    # - Has page_slug
    # - Has template or is_rails_part = true
    # - Template is valid Liquid syntax
  end
  
  it "validates all referenced page parts exist" do
    # Check db/yml_seeds/content_translations/
    # For each page_part_key mentioned, verify page part YML exists
  end
end
```

### 3. **Add Real Seeding Integration Tests**
Update `spec/lib/pwb/seed_runner_spec.rb`:

```ruby
describe "real seeding execution" do
  before do
    # Don't mock - let it actually seed
  end
  
  it "successfully seeds all page parts with valid templates" do
    runner = described_class.new(
      website: website,
      mode: :create_only,
      dry_run: false
    )
    
    expect { runner.execute }.not_to raise_error
    
    # Verify state:
    website.page_parts.each do |page_part|
      unless page_part.is_rails_part
        expect(page_part.template_content).not_to be_empty
      end
    end
  end
  
  it "seeds content without template errors" do
    # Run full seeding and verify no rebuild_page_content errors
  end
end
```

### 4. **Add Theme-Specific Template Tests**
```ruby
describe "theme-specific page part templates" do
  let!(:bristol_website) { create(:pwb_website, theme_name: 'bristol') }
  
  it "loads theme-specific templates when available" do
    # Create app/themes/bristol/page_parts/landing_hero.liquid
    # Seed page part without database template
    # Verify template_content() returns theme template
  end
  
  it "falls back to default theme when theme template missing" do
    # Seed without theme template
    # Verify default template is used
  end
end
```

### 5. **Fix rebuild_page_content to Use template_content()**
**File:** `app/services/pwb/page_part_manager.rb`, line 173

Current (broken):
```ruby
def rebuild_page_content(locale)
  unless page_part && page_part.template
    raise "page_part with valid template not available"
  end
```

Should be:
```ruby
def rebuild_page_content(locale)
  template_content = page_part&.template_content
  unless template_content.present?
    raise "page_part with valid template not available"
  end
```

This will use the proper fallback chain:
1. Database template
2. Theme-specific file
3. Default file
4. Empty string (for rails parts)

### 6. **Validate Page Parts After Seeding**
Add to `spec/libraries/pwb/pages_seeder_spec.rb`:

```ruby
it "ensures all non-rails page parts have valid templates" do
  Pwb::PagesSeeder.seed_page_parts!
  
  invalid_parts = Pwb::PagePart.where(is_rails_part: false).select do |pp|
    pp.template_content.empty?
  end
  
  expect(invalid_parts).to be_empty, 
    "Page parts without templates: #{invalid_parts.map(&:page_part_key).join(', ')}"
end
```

## Testing Strategy Summary

| Test Type | Current Coverage | Recommendation |
|-----------|------------------|-----------------|
| Unit: PagePartManager | Basic methods only | Add rebuild_page_content tests |
| Unit: PagePart | template_content() only | Add integration with PagePartManager |
| Integration: Seeding | Mocked execution | Use real seeding, verify results |
| Integration: Theme templates | None | Add theme-specific template loading tests |
| Validation: YAML seeds | None | Create seed file validator |
| End-to-end: Full website setup | None | Test complete seeding with various themes |

## Key Takeaway

The tests were passing because they tested the happy path with templates already present in the database (from factories). The real-world failure happened when:

1. New theme introduced without template files
2. YAML seed files had no templates (or blank templates)
3. `rebuild_page_content()` tried to use `.template` field directly instead of the `template_content()` fallback chain
4. Missing test for the `rebuild_page_content()` method specifically
5. No validation that templates exist before attempting to render them

Adding comprehensive tests around template loading, validation, and the `rebuild_page_content()` flow would have caught this issue immediately.
