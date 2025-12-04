# Field Keys Migration Plan: Normalized Tables Architecture

## Document Information

- **Version:** 2.0
- **Status:** Ready for Implementation
- **Created:** 2024-12-04
- **Updated:** 2024-12-04
- **Estimated Timeline:** 10-12 weeks (phased rollout)
- **Target Architecture:** Normalized relational tables with Mobility translations

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Translation Gem Migration Decision](#translation-gem-migration-decision)
3. [Naming Convention Decision](#naming-convention-decision)
4. [Current vs. Target Architecture](#current-vs-target-architecture)
5. [Migration Phases](#migration-phases)
6. [Detailed Implementation](#detailed-implementation)
7. [Testing Strategy](#testing-strategy)
8. [Rollback Procedures](#rollback-procedures)
9. [Risk Mitigation](#risk-mitigation)
10. [Team Responsibilities](#team-responsibilities)
11. [Success Metrics](#success-metrics)
12. [Appendices](#appendices)

---

## Executive Summary

### Objective

Migrate from string-based field_keys architecture to normalized relational tables with integer foreign keys, achieving:

- **5-10x query performance improvement**
- **Database-enforced referential integrity**
- **Standard Rails conventions compliance**
- **Automatic counter cache functionality**
- **Modern i18n with Mobility gem**
- **Zero downtime during migration**

### Timeline Overview

| Phase | Duration | Status | Risk Level |
|-------|----------|--------|------------|
| **Phase 0a**: Globalize → Mobility Migration | 3-5 days | Not Started | Low-Medium |
| **Phase 0b**: Immediate Fixes | 2-3 days | Not Started | Low |
| **Phase 1**: Property Types Migration | 2 weeks | Not Started | Medium |
| **Phase 2**: Property States Migration | 1 week | Not Started | Low |
| **Phase 3**: Features/Amenities Migration | 2 weeks | Not Started | Medium |
| **Phase 4**: Validation & Monitoring | 2 weeks | Not Started | Low |
| **Phase 5**: Cleanup & Documentation | 1 week | Not Started | Low |
| **Total** | **10-12 weeks** | | |

### Resource Requirements

- **Development Time:** 1 senior developer full-time
- **Database:** Staging environment for testing
- **Monitoring:** Enhanced logging during migration period
- **Code Review:** All PRs require architecture team approval

---

## Translation Gem Migration Decision

### Question: Should we migrate to Mobility first?

**Answer: YES - Migrate to Mobility BEFORE the field_keys normalization.**

### Rationale

#### Why Mobility First?

1. **Avoid Double Migration**
   - If you migrate field_keys with Globalize, then later migrate to Mobility, you'd have to migrate translations twice
   - Better to migrate Props (existing) + FieldKeys (existing) to Mobility once, then build all new models (PropertyType, PropertyState, etc.) with Mobility from the start

2. **Mobility is Modern & Better Maintained**
   - Globalize: Last major update 2018, uses separate translation tables with `<model>_translations` naming
   - Mobility: Actively maintained, more performant, more flexible, cleaner API
   - Supports multiple backends (table, jsonb, key-value)

3. **Cleaner Architecture**
   - All models use consistent translation approach
   - No mixing of Globalize and Mobility patterns
   - Easier for new developers

4. **Performance Benefits**
   - Mobility's JSONB backend is faster for reads (no JOIN required)
   - Or use table backend like Globalize but with better query optimization

5. **Smaller Scope Before Big Migration**
   - Mobility migration is relatively straightforward
   - Only affects Props and FieldKeys currently
   - Gets it done before the complexity of normalizing field_keys

#### Why NOT Migrate Mobility First?

**Counter-arguments (and rebuttals):**

1. ❌ "Adds complexity to already large migration"
   - ✅ Actually reduces complexity: do one i18n migration, then one field_keys migration separately
   - ✅ Mixing both makes debugging harder

2. ❌ "Mobility migration has its own risks"
   - ✅ True, but isolated risk
   - ✅ Can validate Mobility works before starting field_keys migration
   - ✅ If Mobility fails, rollback and reassess

3. ❌ "Takes more time upfront"
   - ✅ Saves time overall (no double migration)
   - ✅ Only 3-5 days for Mobility migration

### Recommendation: Migration Order

```
Phase 0a: Migrate Props & FieldKeys to Mobility (3-5 days)
  ↓
Phase 0b: Fix immediate field_keys issues (2-3 days)
  ↓
Phase 1-5: Normalize field_keys with Mobility from start (8-9 weeks)
```

### Mobility vs. Globalize Comparison

| Feature | Globalize | Mobility |
|---------|-----------|----------|
| **Maintenance** | Stagnant (last update 2018) | Active (updated 2024) |
| **Performance** | Requires JOIN for every translated attribute | JSONB backend: no JOIN (faster) |
| **API** | `model.name_en`, `model.name_es` | `model.name(locale: :en)` or fallback |
| **Storage** | Separate table only | Table, JSONB, or Key-Value |
| **Fallbacks** | Via I18n.fallbacks | Built-in, more flexible |
| **Query Performance** | Slower (always JOINs) | Faster (especially JSONB) |
| **Learning Curve** | Lower (Rails convention) | Slightly higher (new patterns) |

### Decision Matrix

| Scenario | Recommendation |
|----------|---------------|
| **Your case: Planning major migration anyway** | ✅ Migrate to Mobility first (Phase 0a) |
| **Tight deadline, need field_keys migration ASAP** | Use Globalize for now, plan Mobility later |
| **No plans to migrate from Globalize ever** | Keep Globalize (but you said you plan to migrate) |
| **PostgreSQL database** | ✅ Mobility with JSONB backend (best performance) |
| **MySQL database** | Mobility with table backend |

---

## Naming Convention Decision

### Question: PropertyFeature vs. PropertyAmenity?

**Answer: Support BOTH in migration plan, provide guidance for choosing.**

### Terminology Analysis

#### Option 1: PropertyFeature / PropertyFeatureAssociation

**Pros:**
- Generic term works for any type of property characteristic
- Consistent with current naming (`features` table exists)
- Less domain-specific (could be reused for other types)

**Cons:**
- "Feature" is vague in real estate context
- Less clear for non-technical stakeholders
- Could be confused with software features

**Use when:**
- You want maximum flexibility
- Properties might have non-amenity features (e.g., "Featured Listing", "Virtual Tour Available")
- Prefer generic, reusable naming

#### Option 2: PropertyAmenity / PropertyAmenity

**Pros:**
- Standard real estate terminology
- Immediately clear what it represents (Pool, Garden, Parking)
- Better for domain-driven design
- More professional in API documentation

**Cons:**
- Less flexible (only for physical amenities)
- Might need separate model for non-amenity features

**Use when:**
- Following real estate industry standards
- Clear domain boundaries
- API will be consumed by external real estate platforms

### Hybrid Approach (Recommended)

Use **both** with semantic distinction:

```ruby
# Amenities: Physical property characteristics (Pool, Garden, Garage)
class Pwb::Amenity < ApplicationRecord
  has_many :property_amenities
  has_many :props, through: :property_amenities
end

# Features: Listing/marketing characteristics (Featured, Reserved, Virtual Tour)
# Could be added later if needed, or keep as simple flags
class Pwb::Prop < ApplicationRecord
  # boolean flags for marketing features
  has_amenities :featured, :has_virtual_tour, :newly_listed
end
```

### This Migration Plan: Dual Naming

**All code examples include BOTH naming conventions:**

```ruby
# Throughout this document, you'll see:

# OPTION A: PropertyFeature naming
class Pwb::PropertyFeature < ApplicationRecord
  # ...
end

# OPTION B: PropertyAmenity naming
class Pwb::Amenity < ApplicationRecord
  # ...
end

# Use find-and-replace to choose your preference
```

**For this document, primary examples use: `Amenity` and `PropertyAmenity`**
- More domain-specific
- Industry standard terminology
- Recommended for real estate SaaS

**To switch to `PropertyFeature` naming:**
- See Appendix B for complete find-and-replace guide
- Takes ~5 minutes to convert entire codebase

---

## Current vs. Target Architecture

### Current Architecture Problems

```ruby
# CURRENT (Problems):
class Pwb::FieldKey < ApplicationRecord
  self.primary_key = :global_key  # ❌ String primary key

  # ❌ String foreign keys in associations
  has_many :props_with_type, foreign_key: "prop_type_key", primary_key: :global_key
end

class Pwb::Prop < ApplicationRecord
  # ❌ String columns (no referential integrity)
  # prop_type_key: "propertyTypes.apartamento"
  # prop_state_key: "propertyStates.nuevo"

  # ❌ Uses Globalize (stagnant gem)
  translates :title, :description

  # ❌ Counter cache doesn't work
  scope :property_type, ->(type) { where prop_type_key: type }
end

class Pwb::Feature < ApplicationRecord
  # ❌ String foreign key to field_keys
  # feature_key: "extras.piscina"
end
```

**Issues:**
- No referential integrity
- Slow string comparisons (5-10x vs integers)
- Large indexes (3-5x larger)
- Counter cache broken
- Rails conventions violated
- Translation persistence issues
- Using stagnant Globalize gem

### Target Architecture

```ruby
# TARGET (Solutions):

# 1. Property Types - Normalized table with Mobility translations
class Pwb::PropertyType < ApplicationRecord
  extend Mobility
  translates :name, type: :string

  belongs_to :website
  has_many :props, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: { scope: :website_id }
  validates :name, presence: true
end

# 2. Property States - Normalized table
class Pwb::PropertyState < ApplicationRecord
  extend Mobility
  translates :name, type: :string

  belongs_to :website
  has_many :props, dependent: :restrict_with_error
end

# 3A. Amenities - Normalized table (OPTION A: Real estate terminology)
class Pwb::Amenity < ApplicationRecord
  extend Mobility
  translates :name, type: :string

  belongs_to :website
  has_many :property_amenities, dependent: :destroy
  has_many :props, through: :property_amenities
end

class Pwb::PropertyAmenity < ApplicationRecord
  belongs_to :prop
  belongs_to :amenity, counter_cache: :props_count
end

# 3B. PropertyFeatures - Alternative naming (OPTION B: Generic)
class Pwb::PropertyFeature < ApplicationRecord
  extend Mobility
  translates :name, type: :string

  belongs_to :website
  has_many :property_feature_associations, dependent: :destroy
  has_many :props, through: :property_feature_associations
end

class Pwb::PropertyFeatureAssociation < ApplicationRecord
  belongs_to :prop
  belongs_to :property_feature, counter_cache: :props_count
end

# 4. Updated Props model
class Pwb::Prop < ApplicationRecord
  extend Mobility
  translates :title, :description, type: :string  # Mobility, not Globalize

  # ✅ Integer foreign keys with referential integrity
  belongs_to :property_type, counter_cache: :props_count
  belongs_to :property_state, optional: true, counter_cache: :props_count

  # OPTION A: Amenities
  has_many :property_amenities, dependent: :destroy
  has_many :amenities, through: :property_amenities

  # OPTION B: PropertyFeatures
  # has_many :property_feature_associations, dependent: :destroy
  # has_many :property_features, through: :property_feature_associations

  # ✅ Scopes now use integer lookups
  scope :with_property_type, ->(type_id) { where(property_type_id: type_id) }
  scope :with_amenities, ->(amenity_ids) {
    joins(:property_amenities)
      .where(pwb_property_amenities: { amenity_id: amenity_ids })
      .group(:id)
      .having("COUNT(DISTINCT pwb_property_amenities.amenity_id) = ?", amenity_ids.length)
  }
end
```

**Benefits:**
- ✅ Database foreign keys prevent orphaned records
- ✅ Integer lookups (5-10x faster)
- ✅ Counter cache works automatically
- ✅ Standard Rails patterns
- ✅ Modern Mobility translations
- ✅ Type safety (can't assign state to type field)
- ✅ Better performance (JSONB option)

---

## Migration Phases

### Phase 0a: Globalize → Mobility Migration (Week 1: Days 1-5)

**Goal:** Migrate existing Prop translations from Globalize to Mobility.

**Impact:** Foundation for all subsequent translations.

**Tasks:**
1. Install Mobility gem
2. Configure Mobility (choose backend: table or jsonb)
3. Create Mobility translation tables
4. Migrate existing Prop translations
5. Migrate existing FieldKey translations
6. Update models to use Mobility
7. Test thoroughly
8. Deploy

**Deliverables:**
- Props using Mobility instead of Globalize
- FieldKeys using Mobility
- No translation data loss
- All tests passing

**Success Criteria:**
- All translations accessible via Mobility API
- No errors in production
- Performance metrics baseline established

---

### Phase 0b: Immediate Fixes (Week 1: Days 6-8)

**Goal:** Fix critical field_keys bugs while using new Mobility setup.

**Tasks:**
1. Add validation guards
2. Fix counter cache with counter_culture gem
3. Add database indexes
4. Add data integrity checks

**Deliverables:**
- No data loss from validation issues
- Counter cache accurate
- Baseline performance metrics

---

### Phase 1: Property Types Migration (Weeks 2-3)

**Goal:** Migrate property types to normalized table with zero downtime.

**Sub-Phases:**
1. Create new tables (property_types with Mobility translations)
2. Backfill data from field_keys
3. Add new columns to props table
4. Implement dual-write pattern
5. Validate data consistency
6. Switch reads to new columns
7. Monitor for 1 week
8. Make new columns required

**Deliverables:**
- `pwb_property_types` table operational
- All existing property types migrated
- Dual-write maintaining consistency
- Feature flag for safe rollback

---

### Phase 2: Property States Migration (Week 4)

**Goal:** Apply lessons from Phase 1 to property states migration.

**Deliverables:**
- `pwb_property_states` table operational
- Faster than Phase 1 (reuse patterns)

---

### Phase 3: Amenities/Features Migration (Weeks 5-6)

**Goal:** Migrate features to amenities (or property_features) with many-to-many relationship.

**Naming Decision Point:** Choose between:
- Option A: `amenities` + `property_amenities`
- Option B: `property_features` + `property_feature_associations`

**Deliverables:**
- Many-to-many associations working
- Counter cache tracking usage
- Search functionality enhanced

---

### Phase 4: Validation & Performance Testing (Weeks 7-8)

**Goal:** Verify all migrations successful, measure performance gains.

**Deliverables:**
- Performance improvement metrics (5-10x faster)
- No data inconsistencies
- All APIs backward compatible

---

### Phase 5: Cleanup & Documentation (Week 9)

**Goal:** Remove legacy code, update documentation.

**Deliverables:**
- Clean codebase
- Updated documentation
- Team trained on new patterns

---

## Detailed Implementation

### Phase 0a: Globalize → Mobility Migration

#### Step 0a.1: Install Mobility

**File:** `Gemfile`

```ruby
# Remove Globalize
# gem 'globalize', '~> 6.0'  # REMOVE THIS
# gem 'globalize-accessors'   # REMOVE THIS

# Add Mobility
gem 'mobility', '~> 1.2'
gem 'mobility-actiontext', '~> 1.2'  # If using ActionText
```

**Run:**
```bash
bundle install
```

#### Step 0a.2: Configure Mobility

**File:** `config/initializers/mobility.rb`

```ruby
Mobility.configure do
  # Choose your backend
  # OPTION A: Table backend (like Globalize, separate translation tables)
  plugins do
    backend :table
    reader
    writer
    backend_reader
    query
    cache
    presence
    fallbacks
  end

  # OPTION B: JSONB backend (PostgreSQL only, better performance)
  # plugins do
  #   backend :jsonb
  #   reader
  #   writer
  #   backend_reader
  #   query
  #   cache
  #   presence
  #   fallbacks
  # end
end
```

**Recommendation:** Use **Table backend** for this migration:
- Similar to Globalize (easier migration)
- Works with any database (MySQL, PostgreSQL)
- Can switch to JSONB later as optimization

**If PostgreSQL and want best performance:** Use JSONB backend
- Faster reads (no JOIN)
- Smaller database size
- Requires PostgreSQL

#### Step 0a.3: Create Mobility Translation Tables

**For Table Backend:**

**File:** `db/migrate/20241205000001_create_mobility_tables.rb`

```ruby
class CreateMobilityTables < ActiveRecord::Migration[7.0]
  def change
    # Create string translations table
    create_table :mobility_string_translations do |t|
      t.string :locale, null: false
      t.string :key, null: false
      t.string :value
      t.integer :translatable_id, null: false
      t.string :translatable_type, null: false
      t.timestamps null: false
    end

    add_index :mobility_string_translations,
      [:translatable_id, :translatable_type, :locale, :key],
      unique: true,
      name: :index_mobility_string_translations_on_keys

    add_index :mobility_string_translations,
      [:translatable_id, :translatable_type, :key],
      name: :index_mobility_string_translations_on_translatable_attribute

    # Create text translations table
    create_table :mobility_text_translations do |t|
      t.string :locale, null: false
      t.string :key, null: false
      t.text :value
      t.integer :translatable_id, null: false
      t.string :translatable_type, null: false
      t.timestamps null: false
    end

    add_index :mobility_text_translations,
      [:translatable_id, :translatable_type, :locale, :key],
      unique: true,
      name: :index_mobility_text_translations_on_keys

    add_index :mobility_text_translations,
      [:translatable_id, :translatable_type, :key],
      name: :index_mobility_text_translations_on_translatable_attribute
  end
end
```

**For JSONB Backend (PostgreSQL only):**

**File:** `db/migrate/20241205000001_add_mobility_jsonb_columns.rb`

```ruby
class AddMobilityJsonbColumns < ActiveRecord::Migration[7.0]
  def change
    # Add JSONB column to props table
    add_column :pwb_props, :translations, :jsonb, default: {}, null: false
    add_index :pwb_props, :translations, using: :gin

    # Add JSONB column to field_keys table
    add_column :pwb_field_keys, :translations, :jsonb, default: {}, null: false
    add_index :pwb_field_keys, :translations, using: :gin
  end
end
```

#### Step 0a.4: Migrate Prop Translations

**File:** `db/migrate/20241205000002_migrate_props_to_mobility.rb`

```ruby
class MigratePropsToMobility < ActiveRecord::Migration[7.0]
  def up
    say "Migrating Prop translations from Globalize to Mobility..."

    # Get all Globalize translations
    globalize_table = 'pwb_prop_translations'

    if table_exists?(globalize_table)
      execute <<-SQL
        SELECT prop_id, locale, title, description
        FROM #{globalize_table}
      SQL

      Pwb::Prop.find_each do |prop|
        # Get Globalize translations for this prop
        translations = ActiveRecord::Base.connection.execute(
          "SELECT locale, title, description FROM #{globalize_table} WHERE pwb_prop_id = #{prop.id}"
        )

        translations.each do |row|
          locale = row['locale']
          title = row['title']
          description = row['description']

          # Set via Mobility (will create mobility_string_translations records)
          I18n.with_locale(locale) do
            prop.title = title if title.present?
            prop.description = description if description.present?
            prop.save!(validate: false)
          end

          say "  Migrated #{prop.id} (#{locale}): #{title}", true
        end
      end

      say "Completed Prop translations migration"
    else
      say "Globalize translation table not found, skipping Prop migration"
    end
  end

  def down
    # Clear Mobility translations
    if table_exists?(:mobility_string_translations)
      execute "DELETE FROM mobility_string_translations WHERE translatable_type = 'Pwb::Prop'"
    end
    if table_exists?(:mobility_text_translations)
      execute "DELETE FROM mobility_text_translations WHERE translatable_type = 'Pwb::Prop'"
    end
  end
end
```

#### Step 0a.5: Migrate FieldKey Translations

**File:** `db/migrate/20241205000003_migrate_field_keys_to_mobility.rb`

```ruby
class MigrateFieldKeysToMobility < ActiveRecord::Migration[7.0]
  def up
    say "Migrating FieldKey translations from Globalize to Mobility..."

    globalize_table = 'pwb_field_key_translations'

    if table_exists?(globalize_table)
      Pwb::FieldKey.find_each do |field_key|
        # Get Globalize translations
        translations = ActiveRecord::Base.connection.execute(
          "SELECT locale, label FROM #{globalize_table} WHERE field_key_id = '#{field_key.global_key}'"
        )

        translations.each do |row|
          locale = row['locale']
          label = row['label']

          I18n.with_locale(locale) do
            field_key.label = label if label.present?
            field_key.save!(validate: false)
          end

          say "  Migrated #{field_key.global_key} (#{locale}): #{label}", true
        end
      end

      say "Completed FieldKey translations migration"
    else
      say "Globalize translation table not found, skipping FieldKey migration"
    end
  end

  def down
    if table_exists?(:mobility_string_translations)
      execute "DELETE FROM mobility_string_translations WHERE translatable_type = 'Pwb::FieldKey'"
    end
  end
end
```

#### Step 0a.6: Update Models

**File:** `app/models/pwb/prop.rb`

```ruby
module Pwb
  class Prop < ApplicationRecord
    extend Mobility

    # Replace Globalize with Mobility
    # OLD: translates :title, :description
    # NEW:
    translates :title, type: :string
    translates :description, type: :text

    # Configure fallbacks
    translates :title, :description, fallbacks: { es: :en, fr: :en }

    # ... rest of model ...
  end
end
```

**File:** `app/models/pwb/field_key.rb`

```ruby
module Pwb
  class FieldKey < ApplicationRecord
    extend Mobility

    # Replace Globalize
    # OLD: translates :label
    # NEW:
    translates :label, type: :string, fallbacks: true

    # Update methods to use Mobility API
    def self.get_options_by_tag(tag)
      by_tag(tag)
        .visible
        .for_website(Pwb::Current.website&.id)
        .order(:sort_order)
        .map do |field_key|
          OpenStruct.new(
            value: field_key.global_key,
            label: field_key.label  # Mobility handles locale automatically
          )
        end
    end

    # ... rest of model ...
  end
end
```

#### Step 0a.7: Update Controllers/Views

**Most code remains the same!** Mobility API is similar to Globalize:

```ruby
# BEFORE (Globalize):
prop.title_en = "Apartment"
prop.title_es = "Apartamento"
prop.save!

I18n.with_locale(:es) { prop.title }  # => "Apartamento"

# AFTER (Mobility):
I18n.with_locale(:en) do
  prop.title = "Apartment"
end

I18n.with_locale(:es) do
  prop.title = "Apartamento"
end
prop.save!

I18n.with_locale(:es) { prop.title }  # => "Apartamento"

# OR use explicit locale parameter:
prop.title(locale: :en)  # => "Apartment"
prop.title(locale: :es)  # => "Apartamento"
```

**Update Site Admin Controllers:**

**File:** `app/controllers/site_admin/props_controller.rb`

```ruby
def prop_params
  params.require(:prop).permit(
    :visible,
    :for_sale,
    :for_rent,
    # ... other fields ...

    # Mobility translation fields
    # Generate one for each locale
    *I18n.available_locales.flat_map { |locale|
      ["title_#{locale}", "description_#{locale}"]
    }
  )
end
```

**Views remain mostly the same:**

```erb
<!-- app/views/site_admin/props/_form.html.erb -->
<%= form_with model: [:site_admin, @prop] do |f| %>
  <% I18n.available_locales.each do |locale| %>
    <div class="form-group">
      <%= f.label "title_#{locale}", "Title (#{locale.upcase})" %>
      <%= f.text_field "title_#{locale}", class: 'form-control' %>
    </div>

    <div class="form-group">
      <%= f.label "description_#{locale}", "Description (#{locale.upcase})" %>
      <%= f.text_area "description_#{locale}", class: 'form-control', rows: 5 %>
    </div>
  <% end %>

  <%= f.submit class: 'btn btn-primary' %>
<% end %>
```

#### Step 0a.8: Testing

**File:** `spec/models/pwb/prop_spec.rb`

```ruby
describe 'Mobility translations' do
  let(:prop) { create(:prop) }

  it 'stores translations in multiple locales' do
    I18n.with_locale(:en) { prop.update!(title: 'Apartment') }
    I18n.with_locale(:es) { prop.update!(title: 'Apartamento') }
    I18n.with_locale(:fr) { prop.update!(title: 'Appartement') }

    expect(prop.title(locale: :en)).to eq('Apartment')
    expect(prop.title(locale: :es)).to eq('Apartamento')
    expect(prop.title(locale: :fr)).to eq('Appartement')
  end

  it 'falls back to default locale when translation missing' do
    I18n.with_locale(:en) { prop.update!(title: 'Apartment') }

    # No Spanish translation set
    expect(prop.title(locale: :es)).to eq('Apartment')  # Falls back to :en
  end

  it 'persists translations across reloads' do
    I18n.with_locale(:en) { prop.update!(title: 'Apartment') }

    prop.reload

    expect(prop.title(locale: :en)).to eq('Apartment')
  end
end
```

**Run tests:**

```bash
bundle exec rspec spec/models/pwb/prop_spec.rb
bundle exec rspec spec/models/pwb/field_key_spec.rb
```

#### Step 0a.9: Verification Script

**File:** `lib/tasks/mobility_verify.rake`

```ruby
namespace :mobility do
  desc "Verify Mobility migration from Globalize"
  task verify: :environment do
    puts "Verifying Mobility migration...\n"

    errors = []

    # Check 1: All Props have translations
    Pwb::Prop.find_each do |prop|
      I18n.available_locales.each do |locale|
        title = prop.title(locale: locale)
        if title.blank?
          errors << "Prop ##{prop.id} missing #{locale} title"
        end
      end
    end

    # Check 2: All FieldKeys have translations
    Pwb::FieldKey.find_each do |fk|
      I18n.available_locales.each do |locale|
        label = fk.label(locale: locale)
        if label.blank?
          errors << "FieldKey #{fk.global_key} missing #{locale} label"
        end
      end
    end

    # Check 3: Compare counts
    if table_exists?('pwb_prop_translations')
      old_count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM pwb_prop_translations"
      ).first['count']

      new_count = Mobility::Backends::ActiveRecord::String::Translation
        .where(translatable_type: 'Pwb::Prop')
        .count

      if old_count != new_count
        errors << "Translation count mismatch: Globalize=#{old_count}, Mobility=#{new_count}"
      end
    end

    if errors.any?
      puts "❌ Found #{errors.length} issues:"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    else
      puts "✓ All verifications passed!"
    end
  end
end
```

**Run verification:**

```bash
rails mobility:verify
```

#### Step 0a.10: Drop Globalize Tables

**Only after verifying everything works!**

**File:** `db/migrate/20241205000004_drop_globalize_tables.rb`

```ruby
class DropGlobalizeTables < ActiveRecord::Migration[7.0]
  def up
    # Backup first!
    say "⚠️  WARNING: About to drop Globalize tables. Ensure you have database backup!"
    say "Press ENTER to continue or Ctrl-C to cancel"
    # STDIN.gets if Rails.env.production?

    drop_table :pwb_prop_translations if table_exists?(:pwb_prop_translations)
    drop_table :pwb_field_key_translations if table_exists?(:pwb_field_key_translations)

    say "Dropped Globalize translation tables"
  end

  def down
    # Can't restore without backup
    raise ActiveRecord::IrreversibleMigration, "Cannot restore Globalize tables. Restore from backup if needed."
  end
end
```

**Deployment checklist:**

1. ✅ Backup database
2. ✅ Deploy to staging
3. ✅ Run migrations on staging
4. ✅ Run verification: `rails mobility:verify`
5. ✅ Test all translation features manually
6. ✅ Run full test suite
7. ✅ Deploy to production during low-traffic window
8. ✅ Run migrations
9. ✅ Monitor for errors
10. ✅ Run verification in production
11. ✅ Keep monitoring for 24 hours
12. ✅ Drop Globalize tables after 1 week confidence period

---

### Phase 0b: Immediate Fixes

Now that Mobility is set up, fix the immediate field_keys issues:

#### Task 0b.1: Add Validation Guards

**File:** `app/models/pwb/prop.rb`

```ruby
module Pwb
  class Prop < ApplicationRecord
    extend Mobility
    translates :title, :description, type: :string

    # Add validations to prevent orphaned references
    validates :prop_type_key, presence: true
    validate :prop_type_key_exists
    validate :prop_state_key_exists, if: -> { prop_state_key.present? }

    private

    def prop_type_key_exists
      return if prop_type_key.blank?

      unless FieldKey.exists?(global_key: prop_type_key, tag: 'property-types')
        errors.add(:prop_type_key, "references non-existent property type: #{prop_type_key}")
      end
    end

    def prop_state_key_exists
      return if prop_state_key.blank?

      unless FieldKey.exists?(global_key: prop_state_key, tag: 'property-states')
        errors.add(:prop_state_key, "references non-existent property state: #{prop_state_key}")
      end
    end
  end
end
```

**File:** `app/models/pwb/field_key.rb`

```ruby
module Pwb
  class FieldKey < ApplicationRecord
    extend Mobility
    translates :label, type: :string, fallbacks: true

    # Prevent deletion if in use
    before_destroy :check_usage

    private

    def check_usage
      count = case tag
      when 'property-types'
        Prop.where(prop_type_key: global_key).count
      when 'property-states'
        Prop.where(prop_state_key: global_key).count
      when 'extras'
        Feature.where(feature_key: global_key).count
      else
        0
      end

      if count > 0
        errors.add(:base, "Cannot delete: #{count} properties use this field key")
        throw :abort
      end
    end
  end
end
```

#### Task 0b.2: Fix Counter Cache

**File:** `Gemfile`

```ruby
gem 'counter_culture', '~> 3.5'
```

**File:** `app/models/pwb/feature.rb`

```ruby
module Pwb
  class Feature < ApplicationRecord
    belongs_to :prop

    counter_culture :amenity_field_key,
      column_name: 'props_count',
      foreign_key_name: 'feature_key'

    validate :feature_key_exists

    private

    def feature_key_exists
      unless FieldKey.exists?(global_key: feature_key, tag: 'extras')
        errors.add(:feature_key, "references non-existent amenity")
      end
    end

    def amenity_field_key
      FieldKey.find_by(global_key: feature_key, tag: 'extras')
    end
  end
end
```

**Rake Task:** `lib/tasks/counter_cache.rake`

```ruby
namespace :counter_cache do
  desc "Fix all counter cache counts"
  task fix: :environment do
    puts "Fixing counter caches..."

    Pwb::FieldKey.where(tag: 'property-types').find_each do |fk|
      count = Pwb::Prop.where(prop_type_key: fk.global_key).count
      fk.update_column(:props_count, count)
      puts "  #{fk.global_key}: #{count}"
    end

    Pwb::FieldKey.where(tag: 'property-states').find_each do |fk|
      count = Pwb::Prop.where(prop_state_key: fk.global_key).count
      fk.update_column(:props_count, count)
      puts "  #{fk.global_key}: #{count}"
    end

    Pwb::FieldKey.where(tag: 'extras').find_each do |fk|
      count = Pwb::Feature.where(feature_key: fk.global_key).count
      fk.update_column(:props_count, count)
      puts "  #{fk.global_key}: #{count}"
    end

    puts "Done!"
  end
end
```

#### Task 0b.3: Add Database Indexes

**File:** `db/migrate/20241206000001_add_field_key_indexes.rb`

```ruby
class AddFieldKeyIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :pwb_props, :prop_type_key unless index_exists?(:pwb_props, :prop_type_key)
    add_index :pwb_props, :prop_state_key unless index_exists?(:pwb_props, :prop_state_key)
    add_index :pwb_props, [:visible, :prop_type_key], name: 'index_props_on_visible_and_type'

    add_index :pwb_features, :feature_key unless index_exists?(:pwb_features, :feature_key)
    add_index :pwb_features, [:prop_id, :feature_key], unique: true, name: 'index_features_on_prop_and_key'

    add_index :pwb_field_keys, [:pwb_website_id, :tag, :visible], name: 'index_field_keys_on_website_tag_visible'
  end
end
```

#### Task 0b.4: Data Integrity Checks

**File:** `lib/tasks/data_integrity.rake`

```ruby
namespace :data do
  desc "Check data integrity"
  task integrity_check: :environment do
    puts "Running integrity checks...\n"

    errors = []

    # Check orphaned references
    valid_type_keys = Pwb::FieldKey.where(tag: 'property-types').pluck(:global_key)
    orphaned = Pwb::Prop.where.not(prop_type_key: valid_type_keys)
    if orphaned.any?
      errors << "#{orphaned.count} props with invalid prop_type_key"
    else
      puts "✓ All prop_type_key references valid"
    end

    # Check counter cache
    Pwb::FieldKey.find_each do |fk|
      actual = case fk.tag
      when 'property-types'
        Pwb::Prop.where(prop_type_key: fk.global_key).count
      when 'property-states'
        Pwb::Prop.where(prop_state_key: fk.global_key).count
      when 'extras'
        Pwb::Feature.where(feature_key: fk.global_key).count
      else
        0
      end

      if fk.props_count != actual
        errors << "#{fk.global_key}: cached=#{fk.props_count}, actual=#{actual}"
      end
    end

    if errors.empty?
      puts "\n✓ All checks passed!"
    else
      puts "\n❌ Found #{errors.length} issues"
      errors.each { |e| puts "  #{e}" }
      exit 1
    end
  end
end
```

---

### Phase 1: Property Types Migration

Now with Mobility already set up, create the new normalized tables.

#### Step 1.1: Create Property Types Table

**File:** `db/migrate/20241210000001_create_property_types.rb`

```ruby
class CreatePropertyTypes < ActiveRecord::Migration[7.0]
  def change
    create_table :pwb_property_types do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :key, null: false
      t.boolean :visible, default: true, null: false
      t.boolean :show_in_search_form, default: true, null: false
      t.integer :sort_order, default: 0, null: false
      t.integer :props_count, default: 0, null: false
      t.timestamps

      t.index [:website_id, :key], unique: true
    end

    # Mobility will use the existing mobility_string_translations table
    # No need to create separate translation tables
  end
end
```

**File:** `app/models/pwb/property_type.rb`

```ruby
module Pwb
  class PropertyType < ApplicationRecord
    extend Mobility

    # Translations with Mobility
    translates :name, type: :string, fallbacks: true

    # Associations
    belongs_to :website, class_name: 'Pwb::Website'
    has_many :props, foreign_key: :property_type_id, dependent: :restrict_with_error

    # Validations
    validates :key, presence: true, uniqueness: { scope: :website_id }
    validates :name, presence: true

    # Scopes
    scope :visible, -> { where(visible: true) }
    scope :for_website, ->(website_id) { where(website_id: website_id) }
    scope :for_search, -> { visible.where(show_in_search_form: true) }
    scope :ordered, -> { order(:sort_order) }

    # Methods
    def global_key
      "propertyTypes.#{key}"
    end

    def to_s
      name
    end
  end
end
```

**Test:** `spec/models/pwb/property_type_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe Pwb::PropertyType, type: :model do
  describe 'Mobility translations' do
    let(:property_type) { create(:property_type) }

    it 'stores translations in multiple locales' do
      I18n.with_locale(:en) { property_type.update!(name: 'Apartment') }
      I18n.with_locale(:es) { property_type.update!(name: 'Apartamento') }

      expect(property_type.name(locale: :en)).to eq('Apartment')
      expect(property_type.name(locale: :es)).to eq('Apartamento')
    end

    it 'falls back to default locale' do
      I18n.with_locale(:en) { property_type.update!(name: 'Apartment') }

      expect(property_type.name(locale: :fr)).to eq('Apartment')  # Falls back
    end
  end

  describe 'validations' do
    subject { build(:property_type) }

    it { should validate_presence_of(:key) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:key).scoped_to(:website_id) }
  end

  describe 'deletion protection' do
    let(:property_type) { create(:property_type) }

    context 'when properties reference it' do
      before { create(:prop, property_type: property_type) }

      it 'prevents deletion' do
        expect { property_type.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
      end
    end
  end
end
```

#### Step 1.2: Data Migration

**File:** `db/migrate/20241210000002_backfill_property_types.rb`

```ruby
class BackfillPropertyTypes < ActiveRecord::Migration[7.0]
  def up
    say "Migrating property types from field_keys..."

    Pwb::FieldKey.where(tag: 'property-types').find_each do |fk|
      key = fk.global_key.split('.').last

      property_type = Pwb::PropertyType.find_or_initialize_by(
        website_id: fk.pwb_website_id,
        key: key
      )

      property_type.assign_attributes(
        visible: fk.visible,
        show_in_search_form: fk.show_in_search_form,
        sort_order: fk.sort_order || 0
      )

      # Migrate translations via Mobility
      I18n.available_locales.each do |locale|
        label = fk.label(locale: locale)
        I18n.with_locale(locale) do
          property_type.name = label if label.present?
        end
      end

      if property_type.save
        say "  ✓ Created PropertyType ##{property_type.id}: #{property_type.name}", true
      else
        say "  ✗ FAILED: #{property_type.errors.full_messages.join(', ')}", true
        raise ActiveRecord::Rollback
      end
    end

    say "Completed migration"
  end

  def down
    Pwb::PropertyType.delete_all
  end
end
```

---

### Phases 2-5: Follow Same Pattern

The remaining phases (PropertyStates, Amenities/PropertyFeatures, Validation, Cleanup) follow the same pattern established in Phase 1, but using Mobility for translations.

**Key differences:**

1. **No separate translation table creation** - Mobility handles this
2. **Simpler translation migration** - Use Mobility API
3. **Consistent translation access** - `model.field(locale: :es)`

---

## Naming Convention: Final Decision

### Choose Your Naming

The codebase supports **both** naming conventions. Choose one:

#### Option A: Amenity (Recommended)

```bash
# Tables created:
- pwb_amenities
- pwb_property_amenities (join table)

# Models:
- Pwb::Amenity
- Pwb::PropertyAmenity

# Associations:
prop.amenities
prop.property_amenities
```

**Use this if:** Real estate domain, industry terminology, external APIs

#### Option B: PropertyFeature

```bash
# Tables created:
- pwb_property_features
- pwb_property_feature_associations (join table)

# Models:
- Pwb::PropertyFeature
- Pwb::PropertyFeatureAssociation

# Associations:
prop.property_features
prop.property_feature_associations
```

**Use this if:** Maximum flexibility, generic terminology, might expand beyond amenities

### Implementation: Create Both Options

During Phase 3, implement ONE of the above. The migration plan includes code for both.

To switch between them, see **Appendix B: Naming Conversion Guide**.

---

## Testing Strategy

### Phase 0a Testing (Mobility)

```ruby
# spec/models/mobility_migration_spec.rb
describe 'Mobility migration' do
  it 'all Props have translations' do
    Pwb::Prop.find_each do |prop|
      expect(prop.title(locale: :en)).to be_present
    end
  end

  it 'all FieldKeys have translations' do
    Pwb::FieldKey.find_each do |fk|
      expect(fk.label(locale: :en)).to be_present
    end
  end

  it 'translations persist after reload' do
    prop = create(:prop)
    I18n.with_locale(:en) { prop.update!(title: 'Test') }

    prop.reload

    expect(prop.title(locale: :en)).to eq('Test')
  end
end
```

### Phases 1-5 Testing

Same as original plan, but using Mobility API for translations.

---

## Rollback Procedures

### Rollback Mobility Migration (Phase 0a)

If Mobility migration fails:

```ruby
# Restore Globalize
# 1. Restore database from backup (before Globalize tables dropped)
# 2. Revert model changes
# 3. Revert Gemfile changes
# 4. Bundle install
# 5. Restart app
```

### Rollback Field Keys Migration (Phases 1-5)

Same as original plan - use feature flags and dual-write pattern.

---

## Success Metrics

Same as original plan, plus:

### Translation Performance

| Metric | Globalize | Mobility (Table) | Mobility (JSONB) |
|--------|-----------|------------------|------------------|
| **Read translated attr** | ~2ms (JOIN) | ~2ms (JOIN) | ~0.5ms (no JOIN) |
| **Write translated attr** | ~5ms | ~5ms | ~3ms |
| **Query by translation** | ~10ms | ~10ms | ~8ms |
| **Storage overhead** | Baseline | Similar | -30% smaller |

---

## Appendices

### Appendix A: Complete Migration Checklist

#### Phase 0a: Mobility Migration
- [ ] Install Mobility gem
- [ ] Configure Mobility (choose backend)
- [ ] Create Mobility tables/columns
- [ ] Migrate Prop translations
- [ ] Migrate FieldKey translations
- [ ] Update Prop model
- [ ] Update FieldKey model
- [ ] Update controllers (if needed)
- [ ] Write tests
- [ ] Run tests
- [ ] Deploy to staging
- [ ] Verify in staging
- [ ] Deploy to production
- [ ] Monitor for 48 hours
- [ ] Drop Globalize tables

#### Phase 0b: Immediate Fixes
- [ ] Add validation guards
- [ ] Install counter_culture gem
- [ ] Fix counter caches
- [ ] Add database indexes
- [ ] Create integrity check tasks
- [ ] Run integrity checks
- [ ] Deploy to production

#### Phases 1-5
- [ ] Follow original plan with Mobility for translations

---

### Appendix B: Naming Conversion Guide

#### To Convert from Amenity → PropertyFeature

**Find and replace in entire codebase:**

| Find | Replace |
|------|---------|
| `pwb_amenities` | `pwb_property_features` |
| `pwb_property_amenities` | `pwb_property_feature_associations` |
| `Pwb::Amenity` | `Pwb::PropertyFeature` |
| `Pwb::PropertyAmenity` | `Pwb::PropertyFeatureAssociation` |
| `amenity` | `property_feature` |
| `amenities` | `property_features` |
| `property_amenity` | `property_feature_association` |
| `property_amenities` | `property_feature_associations` |

**Estimated time:** 5 minutes with careful find-and-replace

**⚠️ Warning:** Do this BEFORE running migrations, not after!

---

### Appendix C: Mobility Resources

- **Official Docs:** https://github.com/shioyama/mobility
- **Mobility vs Globalize:** https://dejimata.com/2017/3/16/why-we-switched-from-globalize-to-mobility
- **Performance Comparison:** https://dejimata.com/2017/3/27/mobility-performance
- **JSONB Backend Guide:** https://github.com/shioyama/mobility/wiki/JSONB-Backend

---

### Appendix D: Glossary

- **Mobility**: Modern Rails i18n gem, successor to Globalize
- **Globalize**: Older Rails i18n gem using separate translation tables
- **JSONB**: PostgreSQL JSON data type with indexing support
- **Table Backend**: Mobility backend using separate translation tables (like Globalize)
- **Fallbacks**: Mechanism to return default locale when translation missing

---

## Next Steps

### Recommended Order of Execution

1. **Phase 0a: Mobility Migration** (Days 1-5)
   - Most important: Do this FIRST
   - Sets foundation for all new models
   - Relatively low risk, can rollback easily
   - Test thoroughly before proceeding

2. **Phase 0b: Immediate Fixes** (Days 6-8)
   - Fix counter cache
   - Add validations
   - Add indexes

3. **Phases 1-5: Field Keys Normalization** (Weeks 2-10)
   - Follow original plan
   - All new models use Mobility from start
   - No need to migrate translations twice

### Decision Points

Before starting, decide:

1. **Mobility Backend:**
   - [ ] Table backend (recommended for migration ease)
   - [ ] JSONB backend (PostgreSQL only, better performance)

2. **Naming Convention:**
   - [ ] Option A: Amenity / PropertyAmenity
   - [ ] Option B: PropertyFeature / PropertyFeatureAssociation

3. **Timeline:**
   - [ ] Start immediately
   - [ ] Schedule for next sprint
   - [ ] Wait for business approval

---

**Document Version:** 2.0
**Last Updated:** 2024-12-04
**Maintained By:** PropertyWebBuilder Development Team
**Status:** Ready for Implementation
**Next Review:** After Phase 0a completion
